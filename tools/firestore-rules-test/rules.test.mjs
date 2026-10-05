// Runs firestore.rules in the Firestore emulator:  npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-moneytrack',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const alice = () => env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
const bob = () => env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
const admin = () => env.authenticatedContext('admin1', { email: 'admin@example.com', admin: true }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const record = (updatedAtMs, data = { amount: 5000 }) => ({ data, deleted: false, updatedAtMs, updatedAt: serverTimestamp() });

/** Writes test data directly, bypassing the rules. */
const seed = (path, value) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), value));

describe('synced records', () => {
  const path = 'users/alice/transactions/t1';

  test('owner can write and read their own records', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), record(1000)));
    await assertSucceeds(getDoc(doc(alice(), path)));
  });

  test('another user can neither read nor write them', async () => {
    await seed(path, record(1000));
    await assertFails(getDoc(doc(bob(), path)));
    await assertFails(setDoc(doc(bob(), path), record(2000)));
    await assertFails(getDocs(collection(bob(), 'users/alice/transactions')));
  });

  test('signed-out visitors cannot read them', async () => {
    await seed(path, record(1000));
    await assertFails(getDoc(doc(anon(), path)));
  });

  test('admins can read (support) but never modify user data', async () => {
    await seed(path, record(1000));
    await assertSucceeds(getDoc(doc(admin(), path)));
    await assertSucceeds(getDocs(collection(admin(), 'users/alice/transactions')));
    await assertFails(setDoc(doc(admin(), path), record(2000)));
    await assertFails(setDoc(doc(admin(), 'users/alice/transactions/planted'), record(1000)));
    await assertFails(deleteDoc(doc(admin(), path)));
  });

  test('an older queued edit cannot overwrite a newer one', async () => {
    await seed(path, record(2000, { amount: 999 }));
    await assertFails(setDoc(doc(alice(), path), record(1000)));
    await assertSucceeds(setDoc(doc(alice(), path), record(2000)));
    await assertSucceeds(setDoc(doc(alice(), path), record(3000)));
  });

  test('deletes must be tombstones, not real deletes', async () => {
    await seed(path, record(1000));
    await assertFails(deleteDoc(doc(alice(), path)));
    await assertSucceeds(setDoc(doc(alice(), path), { data: null, deleted: true, updatedAtMs: 2000, updatedAt: serverTimestamp() }));
  });

  test('only known collections and the expected shape are accepted', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/anything/x'), record(1000)));
    await assertFails(setDoc(doc(alice(), path), { ...record(1000), extra: true }));
    await assertFails(setDoc(doc(alice(), path), { ...record(1000), updatedAtMs: 'soon' }));
    await assertFails(setDoc(doc(alice(), path), { data: null, deleted: false, updatedAtMs: 1000 }));
  });
});

describe('profile summary', () => {
  const profile = (extra = {}) => ({ uid: 'alice', email: 'alice@example.com', displayName: 'Alice', lastSeenAt: serverTimestamp(), ...extra });

  test('owner can write their own profile', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'), profile()));
  });

  test('cannot fake the email admins will see', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), profile({ email: 'ceo@bank.ug' })));
  });

  test('cannot add unexpected fields such as a role', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), profile({ role: 'admin' })));
  });

  test('cannot write someone else\'s profile', async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice'), profile()));
  });

  test('only admins can list all users', async () => {
    await seed('users/alice', profile({ lastSeenAt: new Date() }));
    await assertFails(getDocs(collection(alice(), 'users')));
    await assertFails(getDocs(collection(anon(), 'users')));
    await assertSucceeds(getDocs(collection(admin(), 'users')));
  });
});

describe('announcements', () => {
  const ann = (extra = {}) => ({ title: 'Hi', body: 'Welcome', level: 'info', active: true, createdAt: serverTimestamp(), createdBy: 'admin@example.com', ...extra });

  test('anyone, even without an account, can read live announcements', async () => {
    await seed('announcements/live', ann({ createdAt: new Date() }));
    await assertSucceeds(getDocs(query(collection(anon(), 'announcements'), where('active', '==', true))));
    await assertSucceeds(getDoc(doc(alice(), 'announcements/live')));
  });

  test('drafts (inactive) are only visible to admins', async () => {
    await seed('announcements/draft', ann({ active: false, createdAt: new Date() }));
    await assertFails(getDoc(doc(anon(), 'announcements/draft')));
    await assertFails(getDocs(collection(alice(), 'announcements')));
    await assertSucceeds(getDoc(doc(admin(), 'announcements/draft')));
  });

  test('only admins can publish, edit and delete', async () => {
    await assertFails(addDoc(collection(alice(), 'announcements'), ann()));
    const ref = await assertSucceeds(addDoc(collection(admin(), 'announcements'), ann()));
    await assertFails(updateDoc(doc(alice(), `announcements/${ref.id}`), { active: false }));
    await assertSucceeds(updateDoc(doc(admin(), `announcements/${ref.id}`), { active: false }));
    await assertSucceeds(deleteDoc(doc(admin(), `announcements/${ref.id}`)));
  });

  test('invalid announcements are rejected', async () => {
    await assertFails(addDoc(collection(admin(), 'announcements'), ann({ level: 'scam' })));
    await assertFails(addDoc(collection(admin(), 'announcements'), ann({ title: 'x'.repeat(201) })));
  });
});

describe('admin audit log', () => {
  const entry = (extra = {}) => ({ adminUid: 'admin1', adminEmail: 'admin@example.com', action: 'view_user', targetUid: 'alice', at: serverTimestamp(), ...extra });

  test('an admin can record their own access, stamped with server time', async () => {
    await assertSucceeds(addDoc(collection(admin(), 'admin_audit'), entry()));
  });

  test('entries cannot be forged, back-dated or written by non-admins', async () => {
    await assertFails(addDoc(collection(admin(), 'admin_audit'), entry({ adminUid: 'someone-else' })));
    await assertFails(addDoc(collection(admin(), 'admin_audit'), entry({ at: new Date(2020, 0, 1) })));
    await assertFails(addDoc(collection(alice(), 'admin_audit'), entry({ adminUid: 'alice' })));
  });

  test('the log is append-only and admin-only', async () => {
    await seed('admin_audit/e1', entry({ at: new Date() }));
    await assertFails(updateDoc(doc(admin(), 'admin_audit/e1'), { action: 'nothing' }));
    await assertFails(deleteDoc(doc(admin(), 'admin_audit/e1')));
    await assertFails(getDocs(collection(alice(), 'admin_audit')));
    await assertSucceeds(getDocs(collection(admin(), 'admin_audit')));
  });
});
