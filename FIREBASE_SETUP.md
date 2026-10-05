# Online mode + admin dashboard: setup (Firebase)

MoneyTrack now has an **optional** cloud mode and a separate **admin
dashboard**. Both are built and tested in this repo but switched off until
you connect your own Firebase project. Until then the app behaves exactly
as before: fully offline, no account, and the cloud screens say "not set
up in this build".

Do the steps below on your own computer, in order. Each step ends with a
**Check** so you know it worked before moving on.

---

## How it works (2-minute read)

**Offline first, always.** The app still reads and writes everything in
its on-phone database (Hive). The internet is never needed to use it.

**Online = backup + sync, only if the user signs in.**
`Settings → Backup & sync` lets a user create an account (email +
password). From then on:

- Every change is uploaded in the background. With no connection, the
  change waits on the phone and uploads when the connection returns,
  even if the app was closed in between.
- Signing in on a new phone restores everything.
- If two phones edit the same thing, the most recent edit wins.
- The **app-lock PIN never leaves the phone**. Receipt photos aren't
  uploaded yet (only their file names are).
- If someone signs in with a *different* account on a phone that already
  holds another account's data, nothing is mixed. The app asks first
  ("Replace this phone's data" or "Keep it and sign out").

**Admin dashboard** (`admin/`, a website, never inside the APK):

- **Overview**: total users, active in last 7 / 30 days, new sign-ups,
  transactions logged.
- **Users**: search by email and open a user to help them. This view is
  **read-only**, and every time an admin opens someone's data an entry
  is written to an append-only audit log.
- **Announcements**: publish a message, warning or "please update" notice
  that appears on everyone's home screen, with or without an account.

**Who can see what** is enforced by `firestore.rules`, not by the apps:
users can only touch their own data; admins can read but never change it;
the audit log can't be edited or deleted. There are 19 automated tests
for these rules (`tools/firestore-rules-test`).

---

## Step 0: Install the tools (once)

You need Flutter (you already have it), Node.js 20+ (https://nodejs.org),
and Java 21 for the local test emulator (optional).

```sh
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login          # opens your browser
```

**Check:** `firebase --version` and `flutterfire --version` both print a version.
(If `flutterfire` isn't found, add `~/.pub-cache/bin` (macOS/Linux) or
`%LOCALAPPDATA%\Pub\Cache\bin` (Windows) to your PATH.)

## Step 1: Create the Firebase project

1. Go to https://console.firebase.google.com → **Create a project** →
   name it e.g. `moneytrack`. Google Analytics is optional (you can turn it off).
2. **Build → Authentication → Get started → Sign-in method →
   Email/Password → Enable → Save.**
3. **Build → Firestore Database → Create database.**
   - Location: pick the closest to your users (e.g. `africa-south1`
     Johannesburg, or `eur3` Europe). **This can't be changed later.**
   - Start in **production mode** (our rules replace the defaults in Step 4).

**Check:** Authentication shows Email/Password as *Enabled*; Firestore shows an empty database.

## Step 2: Link this repo to the project

From the repo root:

```sh
git pull                 # make sure you're on the latest main
firebase use --add       # pick your project, alias: default
```

This creates `.firebaserc`. Commit it (it only names the project).

## Step 3: Connect the mobile app

```sh
flutterfire configure --platforms=android,ios
```

This **replaces** the placeholder `lib/firebase_options.dart` with your
real config and adds `android/app/google-services.json` (+ the iOS
equivalent). These are safe to commit; Firebase protects data with the
security rules, not by hiding these IDs.

```sh
flutter pub get
flutter run
```

**Check:** In the app, `Settings → Backup & sync` now says
*"Optional — sign in to back up your data"* instead of *"Not set up in this build"*.

> If the Android build complains about `minSdkVersion`, set
> `minSdk = 23` in `android/app/build.gradle.kts` (`defaultConfig`).
> On iOS, set `platform :ios, '13.0'` (or higher) in `ios/Podfile`.

## Step 4: Deploy the security rules and index

```sh
firebase deploy --only firestore
```

**Check:** Firebase console → Firestore → **Rules** shows the MoneyTrack
rules; **Indexes** shows one index on `announcements` (it may take a few
minutes to finish building).

⚠️ Don't skip this. Without it, Firestore uses the console's default rules.

## Step 5: Create your account and make yourself admin

1. In the app: `Settings → Backup & sync → Create account` with your email.
   (Or Firebase console → Authentication → **Add user**.)
2. Grant yourself the admin role. Pick **one** way to give the script access:

   **a) Without a key file (recommended)**, if you have the
   [gcloud CLI](https://cloud.google.com/sdk/docs/install):
   ```sh
   gcloud auth application-default login
   cd tools/admin
   npm install
   node set-admin.js --project YOUR_PROJECT_ID you@example.com
   ```

   **b) With a service-account key:** Firebase console → ⚙ Project
   settings → **Service accounts → Generate new private key**. Save it
   **outside the repo** (e.g. Downloads), then:
   ```sh
   cd tools/admin
   npm install
   node set-admin.js --project YOUR_PROJECT_ID --key ~/Downloads/key.json you@example.com
   ```
   Delete the key file afterwards. It gives full control of the project.

**Check:** `node set-admin.js --project YOUR_PROJECT_ID --list` prints your email.

Remove someone later with `... their@email.com --remove`.

## Step 6: Run the admin dashboard

```sh
cd admin
flutterfire configure --platforms=web     # same project; replaces admin/lib/firebase_options.dart
flutter pub get
flutter run -d chrome
```

Sign in with the account from Step 5.

**Check:** You land on **Overview** and see yourself as 1 user. If you see
*"is not an admin"*, sign out and in again (the role is read at sign-in).

### Put it online

```sh
cd admin && flutter build web && cd ..
firebase deploy --only hosting
```

It's then live at `https://YOUR_PROJECT_ID.web.app`. Only admin accounts
can see any data there; everyone else gets "not an admin".

## Step 7: Test online + offline on a real phone (10 min)

1. Sign in on the phone (`Backup & sync`). Add a transaction.
   → Admin dashboard → **Users** → you → it's listed under *Recent transactions*.
2. Turn on **airplane mode**. Add two more transactions. The app works
   normally; `Backup & sync` shows *"Offline — 2 change(s) waiting"*.
3. Turn airplane mode off. Within a few seconds they upload (the count
   drops to 0) and appear in the dashboard.
4. Dashboard → **Announcements → New announcement** → publish.
   → Reopen the app's home screen: the banner shows. Tap ✕ to dismiss.
5. (Optional) Install on a second phone, sign in with the same account:
   all data restores.

## Shipping it (and Shorebird)

This change adds new native plugins (Firebase, connectivity), so it
**can't be shipped as a Shorebird patch**. Do Steps 1–4 first, then make
a **new full release**: bump `version:` in `pubspec.yaml` and
`shorebird release android --artifact apk` (see `SHOREBIRD_SETUP.md`).
After that, Dart-only changes can go out as patches again.

Rule changes (`firestore.rules`) and dashboard changes are deployed with
`firebase deploy`. They never need an app release.

## Running the tests

```sh
flutter test                                   # app, incl. 24 sync/codec tests
cd tools/firestore-rules-test && npm install && npm test   # security rules (needs Java)
```

## Costs

Everything here fits Firebase's free **Spark** plan for a small user base.
At the time of writing that includes 50,000 Firestore reads, 20,000 writes
and 1 GiB storage per day. Check https://firebase.google.com/pricing.
You don't need the paid plan for anything in this setup.

## Before publishing on the Play Store: still to do

These aren't built yet and are needed before a public Play Store release:

- **In-app account deletion.** Google Play requires apps that let users
  create an account to also let them delete it (in the app *and* via a
  web link). The rules intentionally block deletes from the app, so this
  should be a small Cloud Function.
- **Privacy policy + Play "Data safety" form**, declaring that you store
  account email, phone, income profile and financial records, and that
  admins can view them for support.

Nice-to-have next: upload receipt photos (Firebase Storage), Google or
phone-number sign-in, and push notifications for announcements (FCM).

## Where things are

| What | Where |
|---|---|
| Firebase startup (falls back to offline) | `lib/services/cloud/firebase_bootstrap.dart` |
| Optional sign-in | `lib/services/cloud/auth_service.dart`, `lib/ui/account/cloud_account_screen.dart` |
| Sync engine | `lib/services/cloud/sync_service.dart` |
| Model ⇄ cloud mapping (**update when adding a model field**) | `lib/services/cloud/cloud_codec.dart` |
| Announcements in the app | `lib/services/cloud/announcement_service.dart`, `lib/ui/widgets/announcement_banner.dart` |
| Admin dashboard | `admin/` |
| Who can read/write what | `firestore.rules` (+ tests in `tools/firestore-rules-test`) |
| Grant/revoke admins | `tools/admin/set-admin.js` |

Cloud data layout: `users/{uid}` (profile summary for the dashboard),
`users/{uid}/{box}/{id}` (one document per local record: `data`,
`deleted`, `updatedAtMs`), `announcements/{id}`, `admin_audit/{id}`.
