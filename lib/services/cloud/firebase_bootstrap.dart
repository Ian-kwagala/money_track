import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase if this build has been configured for it.
///
/// Cloud features are strictly optional: when Firebase is not configured
/// (placeholder `firebase_options.dart`) or fails to start, [isReady] stays
/// false and the app keeps working fully offline on Hive.
class FirebaseBootstrap {
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // Mobile keeps an on-device cache of everything it has read, and queues
      // writes made while offline until the connection comes back.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('Cloud features disabled: $e');
    }
  }
}
