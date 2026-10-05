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
flutter run -d chrome
```
