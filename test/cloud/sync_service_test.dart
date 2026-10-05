import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:money_track/data/hive_boxes.dart';
import 'package:money_track/data/money_repository.dart';
import 'package:money_track/models/app_settings.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/models/user.dart';
import 'package:money_track/services/cloud/auth_service.dart';
import 'package:money_track/services/cloud/cloud_codec.dart';
import 'package:money_track/services/cloud/connectivity_service.dart';
import 'package:money_track/services/cloud/sync_service.dart';

/// Stands in for Firebase Auth. AuthService's own constructor does nothing
/// when Firebase isn't initialised, which is always the case in tests.
class FakeAuth extends AuthService {
  final _changes = StreamController<fb.User?>.broadcast();
  String? _uid;
  String? _email;

  void signInAs(String uid) {
    _uid = uid;
    _email = '$uid@example.com';
    _changes.add(null);
  }

  @override
  bool get isAvailable => true;
  @override
  bool get isSignedIn => _uid != null;
  @override
  String? get uid => _uid;
  @override
  String? get email => _email;
  @override
  String? get displayName => null;
  @override
  DateTime? get accountCreatedAt => DateTime(2026, 1, 1);
  @override
  Stream<fb.User?> get userChanges => _changes.stream;
  @override
  Future<void> signOut() async {
    _uid = null;
    _email = null;
    _changes.add(null);
  }
}

/// One simulated phone: its own Hive storage + sync service, sharing the
/// cloud with any other "phone" in the same test.
class Phone {
  Phone._(this.repo, this.auth, this.sync);

  final MoneyRepository repo;
  final FakeAuth auth;
  final SyncService sync;
  int remoteApplied = 0;

  static Future<Phone> boot(FakeFirebaseFirestore cloud) async {
    final dir = await Directory.systemTemp.createTemp('mt_sync_test');
    final repo = MoneyRepository();
    await repo.init(hivePath: dir.path);
    final auth = FakeAuth();
    final sync = SyncService(
      repo: repo,
      auth: auth,
      connectivity: ConnectivityService.manual(online: true),
      firestore: cloud,
      enabled: true,
    );
    final phone = Phone._(repo, auth, sync);
    sync.onRemoteChangesApplied = () => phone.remoteApplied++;
    return phone;
  }

  Future<void> shutdown() async {
    sync.dispose();
    await Hive.close();
  }
}

/// Lets Hive's box.watch() events and auth stream events be delivered.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

TxRecord tx(String id, double amount) =>
    TxRecord(id: id, type: TxType.expense, amount: amount, walletId: 'w', dateTime: DateTime(2026, 9, 1));

void main() {
  late FakeFirebaseFirestore cloud;
  late Phone phone;

  CollectionReference<Map<String, dynamic>> col(String uid, String box) =>
      cloud.collection('users').doc(uid).collection(box);

  Future<Map<String, dynamic>?> cloudDoc(String uid, String box, String id) async =>
      (await col(uid, box).doc(id).get()).data();

  setUp(() async {
    cloud = FakeFirebaseFirestore();
    phone = await Phone.boot(cloud);
  });

  tearDown(() => phone.shutdown());

  test('first sign-in uploads all local data, but never the app-lock PIN', () async {
    final s = phone.repo.settings
      ..appLockEnabled = true
      ..appLockPin = '1234';
    await phone.repo.updateSettings(s);
    await phone.repo.addTransaction(tx('t1', 5000));

    phone.auth.signInAs('u1');
    await phone.sync.start();
    await phone.sync.flushNow();

    final t = await cloudDoc('u1', HiveBoxes.transactions, 't1');
    expect(t?['deleted'], isFalse);
    expect((t?['data'] as Map)['amount'], 5000);

    final settings = await cloudDoc('u1', HiveBoxes.settings, 'default');
    expect(settings, isNotNull);
    expect((settings!['data'] as Map).containsKey('appLockPin'), isFalse);
    expect(settings.toString(), isNot(contains('1234')));

    final profile = (await cloud.collection('users').doc('u1').get()).data();
    expect((profile?['counts'] as Map)['transactions'], 1);
    expect(phone.sync.pendingCount, 0);
    expect(phone.sync.status, SyncStatus.synced);
  });

  test('edits and deletes are pushed; deletes become tombstones', () async {
    phone.auth.signInAs('u1');
    await phone.sync.start();

    await phone.repo.addTransaction(tx('t1', 100));
    await settle();
    await phone.sync.flushNow();
    expect(((await cloudDoc('u1', HiveBoxes.transactions, 't1'))!['data'] as Map)['amount'], 100);

    await phone.repo.updateTransaction(tx('t1', 250));
    await settle();
    await phone.sync.flushNow();
    expect(((await cloudDoc('u1', HiveBoxes.transactions, 't1'))!['data'] as Map)['amount'], 250);

    await phone.repo.deleteTransaction('t1');
    await settle();
    await phone.sync.flushNow();
    final doc = await cloudDoc('u1', HiveBoxes.transactions, 't1');
    expect(doc!['deleted'], isTrue);
    expect(doc['data'], isNull);
    expect(phone.sync.pendingCount, 0);
  });

  test('a newer cloud edit is applied locally without echoing back', () async {
    phone.auth.signInAs('u1');
    await phone.repo.addTransaction(tx('t1', 100));
    await phone.sync.start();
    await phone.sync.flushNow();

    await col('u1', HiveBoxes.transactions).doc('t1').set({
      'data': CloudCodec.encode(HiveBoxes.transactions, tx('t1', 999)),
      'deleted': false,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch + 60000,
    });
    await phone.sync.syncNow();
    await settle();

    expect(phone.repo.transactions.single.amount, 999);
    expect(phone.remoteApplied, greaterThan(0));
    expect(phone.sync.pendingCount, 0, reason: 'applying a cloud change must not mark it dirty again');

    // ...and the next real edit to that same record must still upload.
    await phone.repo.updateTransaction(tx('t1', 1234));
    await settle();
    await phone.sync.flushNow();
    expect(((await cloudDoc('u1', HiveBoxes.transactions, 't1'))!['data'] as Map)['amount'], 1234);
  });

  test('a local edit newer than the cloud copy wins', () async {
    phone.auth.signInAs('u1');
    await phone.sync.start();
    await phone.repo.addTransaction(tx('t1', 100));
    await settle();
    await phone.sync.flushNow();

    // Another device wrote an older version (its clock/edit was earlier).
    final localStamp = (await cloudDoc('u1', HiveBoxes.transactions, 't1'))!['updatedAtMs'] as int;
    await col('u1', HiveBoxes.transactions).doc('t1').set({
      'data': CloudCodec.encode(HiveBoxes.transactions, tx('t1', 1)),
      'deleted': false,
      'updatedAtMs': localStamp - 5000,
    });
    await phone.repo.updateTransaction(tx('t1', 300));
    await settle();
    await phone.sync.syncNow();
    await phone.sync.flushNow();

    expect(phone.repo.transactions.single.amount, 300);
    expect(((await cloudDoc('u1', HiveBoxes.transactions, 't1'))!['data'] as Map)['amount'], 300);
  });

  test('a delete made on another device removes the record here', () async {
    phone.auth.signInAs('u1');
    await phone.repo.addTransaction(tx('t1', 100));
    await phone.sync.start();
    await phone.sync.flushNow();

    await col('u1', HiveBoxes.transactions).doc('t1').set({
      'data': null,
      'deleted': true,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch + 60000,
    });
    await phone.sync.syncNow();

    expect(phone.repo.transactions, isEmpty);
  });

  test('changes made while signed out upload when the user signs back in', () async {
    await phone.sync.start();
    expect(phone.sync.status, SyncStatus.signedOut);

    await phone.repo.addTransaction(tx('offline1', 4200));
    await settle();
    expect(phone.sync.pendingCount, greaterThan(0));
    expect(await cloudDoc('u1', HiveBoxes.transactions, 'offline1'), isNull);

    phone.auth.signInAs('u1');
    await settle();
    await phone.sync.flushNow();
    expect(((await cloudDoc('u1', HiveBoxes.transactions, 'offline1'))!['data'] as Map)['amount'], 4200);
  });

  test('a new phone restores the account\'s data on sign-in', () async {
    // Phone A: record data and back it up.
    phone.auth.signInAs('u1');
    await phone.repo.addTransaction(tx('t1', 7000));
    await phone.sync.start();
    await phone.sync.flushNow();
    await phone.shutdown();

    // Phone B: fresh install, same account.
    phone = await Phone.boot(cloud);
    expect(phone.repo.transactions, isEmpty);
    phone.auth.signInAs('u1');
    await phone.sync.start();
    await phone.sync.flushNow();

    expect(phone.repo.transactions.map((t) => t.id), ['t1']);
    expect(phone.repo.transactions.single.amount, 7000);
    expect((await col('u1', HiveBoxes.transactions).get()).docs, hasLength(1));
  });

  test('another account signing in on this phone never gets this phone\'s data', () async {
    await phone.repo.updateSettings(phone.repo.settings
      ..appLockEnabled = true
      ..appLockPin = '1234');
    await phone.repo.saveUser(User(name: 'Alice', phone: '0772000111', email: 'alice@example.com'));
    phone.auth.signInAs('u1');
    await phone.repo.addTransaction(tx('mine', 100));
    await phone.sync.start();
    await phone.sync.flushNow();

    // u2 already has a backup in the cloud.
    await col('u2', HiveBoxes.transactions).doc('theirs').set({
      'data': CloudCodec.encode(HiveBoxes.transactions, tx('theirs', 555)),
      'deleted': false,
      'updatedAtMs': 1000,
    });
    await col('u2', HiveBoxes.settings).doc('default').set({
      'data': CloudCodec.encode(HiveBoxes.settings, AppSettings(profileName: 'Bob', onboardingCompleted: true)),
      'deleted': false,
      'updatedAtMs': 1000,
    });

    await phone.auth.signOut();
    await settle();
    phone.auth.signInAs('u2');
    await settle();

    expect(phone.sync.status, SyncStatus.needsAccountChoice);
    expect(await cloudDoc('u2', HiveBoxes.transactions, 'mine'), isNull,
        reason: 'u1\'s records must not be uploaded into u2\'s account');

    await phone.sync.replaceLocalWithAccount();
    await phone.sync.flushNow();

    expect(phone.repo.transactions.map((t) => t.id), ['theirs']);
    expect(phone.repo.settings.profileName, 'Bob');
    expect(phone.repo.settings.appLockPin, '1234', reason: 'the device lock survives an account switch');
    expect(await cloudDoc('u2', HiveBoxes.transactions, 'mine'), isNull);
    expect(phone.repo.currentUser.name, isNot('Alice'));
    final u2Everything = (await cloud.collection('users').doc('u2').get()).data().toString() +
        [for (final box in CloudCodec.syncedBoxes) (await col('u2', box).get()).docs.map((d) => d.data())].toString();
    expect(u2Everything, isNot(contains('Alice')));
    expect(u2Everything, isNot(contains('0772000111')));
  });

  test('switching to a brand-new account with no backup gets default categories and wallets', () async {
    phone.auth.signInAs('u1');
    await phone.sync.start();
    await phone.sync.flushNow();
    await phone.auth.signOut();
    await settle();
    phone.auth.signInAs('fresh');
    await settle();
    await phone.sync.replaceLocalWithAccount();
    await phone.sync.flushNow();

    expect(phone.repo.categories, isNotEmpty);
    expect(phone.repo.wallets, isNotEmpty);
    expect((await col('fresh', HiveBoxes.categories).get()).docs, isNotEmpty);
  });
}
