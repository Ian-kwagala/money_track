# MoneyTrack Admin

Flutter Web dashboard for MoneyTrack administrators: user stats, user
lookup for support (read-only, access is audit-logged) and in-app
announcements.

It is a separate app from the mobile client and is never shipped inside
the APK. Setup, granting admin access and deployment are covered in
[`../FIREBASE_SETUP.md`](../FIREBASE_SETUP.md).

```sh
cd admin
flutter pub get
flutter run -d chrome     # run it locally
flutter test              # widget tests (fake Firebase, no network)
```

Published at https://moneytracker-cb825.web.app with
`flutter build web --release` here, then `firebase deploy --only hosting`
from the repo root.

Pages use `AdminServices` (lib/services.dart) for auth and the database
rather than the Firebase singletons, so tests can swap in fakes.
