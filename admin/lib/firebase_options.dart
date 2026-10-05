// PLACEHOLDER — overwritten by `flutterfire configure --platforms=web`
// run from the admin/ folder (see FIREBASE_SETUP.md).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured for the admin dashboard yet. Run '
        '`flutterfire configure --platforms=web` inside admin/ (see FIREBASE_SETUP.md).',
      );
}
