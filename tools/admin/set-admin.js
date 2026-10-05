#!/usr/bin/env node
// Grants (or removes) the MoneyTrack admin role on an existing account.
//
// The role is a Firebase custom claim (`admin: true`) baked into the user's
// signed ID token. firestore.rules and the admin dashboard both check it,
// and users can't set it themselves.
//
// Usage (from tools/admin, after `npm install`):
//   node set-admin.js --project <firebase-project-id> <email>            # grant
//   node set-admin.js --project <firebase-project-id> <email> --remove   # revoke
//   node set-admin.js --project <id> --list                              # show admins
//
// Credentials, either:
//   * `gcloud auth application-default login` once (recommended, no key file), or
//   * --key path/to/service-account.json  (keep it OUT of the repo; delete it after)
//
// The person must sign out of the dashboard and back in for a change to apply.

const path = require('node:path');
const { applicationDefault, cert, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

function parseArgs(argv) {
  const opts = { remove: false, list: false, project: undefined, key: undefined, email: undefined };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--remove') opts.remove = true;
    else if (a === '--list') opts.list = true;
    else if (a === '--project') opts.project = argv[++i];
    else if (a === '--key') opts.key = argv[++i];
    else if (a === '-h' || a === '--help') opts.help = true;
    else if (!a.startsWith('--')) opts.email = a;
    else throw new Error(`Unknown option ${a}`);
  }
  return opts;
}

function usage() {
  console.log('Usage: node set-admin.js --project <id> [--key key.json] (<email> [--remove] | --list)');
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help || (!opts.email && !opts.list) || !opts.project) {
    usage();
    process.exit(opts.help ? 0 : 1);
  }

  initializeApp({
    projectId: opts.project,
    credential: opts.key ? cert(require(path.resolve(opts.key))) : applicationDefault(),
  });
  const auth = getAuth();

  if (opts.list) {
    let pageToken;
    let found = 0;
    do {
      const page = await auth.listUsers(1000, pageToken);
      for (const u of page.users) {
        if (u.customClaims && u.customClaims.admin === true) {
          console.log(`${u.email ?? '(no email)'}  ${u.uid}`);
          found++;
        }
      }
      pageToken = page.pageToken;
    } while (pageToken);
    if (!found) console.log('No admins yet.');
    return;
  }

  const user = await auth.getUserByEmail(opts.email);
  const claims = { ...(user.customClaims || {}) };
  if (opts.remove) delete claims.admin;
  else claims.admin = true;
  await auth.setCustomUserClaims(user.uid, claims);
  console.log(`${opts.remove ? 'Removed admin from' : 'Granted admin to'} ${user.email} (${user.uid}).`);
  console.log('They must sign out of the admin dashboard and sign in again.');
}

main().catch((e) => {
  if (e && e.code === 'auth/user-not-found') {
    console.error('No account with that email. Create it first (sign up in the app, or Firebase console > Authentication > Add user).');
  } else {
    console.error(e && e.message ? e.message : e);
  }
  process.exit(1);
});
