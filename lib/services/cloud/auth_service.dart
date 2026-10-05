import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Optional account for cloud backup & sync. The app never requires it.
class AuthService extends ChangeNotifier {
  AuthService() {
    if (!FirebaseBootstrap.isReady) return;
    _user = fb.FirebaseAuth.instance.currentUser;
    _sub = fb.FirebaseAuth.instance.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  StreamSubscription<fb.User?>? _sub;
  fb.User? _user;

  /// False when this build has no Firebase config; hide all account UI then.
  bool get isAvailable => FirebaseBootstrap.isReady;
  bool get isSignedIn => _user != null;
  String? get uid => _user?.uid;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;
  DateTime? get accountCreatedAt => _user?.metadata.creationTime;

  Stream<fb.User?> get userChanges =>
      isAvailable ? fb.FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  Future<void> signIn(String email, String password) => _guard(() =>
      fb.FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> createAccount(String name, String email, String password) => _guard(() async {
        final cred = await fb.FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email.trim(), password: password);
        if (name.trim().isNotEmpty) await cred.user?.updateDisplayName(name.trim());
      });

  Future<void> sendPasswordReset(String email) =>
      _guard(() => fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _guard(() => fb.FirebaseAuth.instance.signOut());

  Future<void> _guard(Future<void> Function() action) async {
    if (!isAvailable) throw const AuthFailure('Cloud accounts are not set up in this build.');
    try {
      await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  static String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address looks wrong.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Sign in instead.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return 'No internet connection. Signing in needs to be online once.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      default:
        return 'Something went wrong ($code). Please try again.';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
