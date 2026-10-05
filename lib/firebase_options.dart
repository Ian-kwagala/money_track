// PLACEHOLDER — overwritten by `flutterfire configure` (see FIREBASE_SETUP.md).
//
// Until then, reading currentPlatform throws, FirebaseBootstrap catches it,
// and the app runs exactly as before: fully offline, cloud features hidden.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured yet. Run `flutterfire configure` '
        'from the project root (see FIREBASE_SETUP.md).',
      );
}
