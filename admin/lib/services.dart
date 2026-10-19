import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The signed-in person, as far as the dashboard cares.
class AdminAccount {
  const AdminAccount({required this.uid, required this.email, required this.isAdmin});

  final String uid;
  final String email;

  /// The `admin` custom claim (granted with tools/admin/set-admin.js and
  /// enforced by firestore.rules; this only decides what to show).
  final bool isAdmin;
}

/// A failure worded for the person at the screen.
class AdminAuthException implements Exception {
  const AdminAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What the dashboard needs from Firebase Auth. Pages use this rather than
/// FirebaseAuth directly, so they can be tested with a fake.
abstract class AdminAuth {
  /// Null when signed out. Each sign-in re-reads the admin claim.
  Stream<AdminAccount?> accountChanges();

  Future<void> signIn({required String email, required String password});

  /// Emails a link to choose a new password. Says nothing about whether the
  /// address has an account.
  Future<void> sendPasswordReset(String email);

  /// Checks [current] first, as Firebase requires a recent sign-in.
  Future<void> changePassword({required String current, required String next});

  Future<void> signOut();
}

class FirebaseAdminAuth implements AdminAuth {
  FirebaseAdminAuth([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AdminAccount?> accountChanges() => _auth.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        // Force a refresh so a newly granted claim is picked up.
        final token = await user.getIdTokenResult(true);
        return AdminAccount(uid: user.uid, email: user.email ?? '', isAdmin: token.claims?['admin'] == true);
      });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password), _signInMessage);

  @override
  Future<void> sendPasswordReset(String email) async {
    // After choosing a new password, "Continue" leads back to this dashboard.
    final back = kIsWeb ? ActionCodeSettings(url: Uri.base.origin) : null;
    try {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim(), actionCodeSettings: back);
      } on FirebaseAuthException catch (e) {
        // A domain Firebase doesn't know: send the plain link instead.
        if (back == null || !e.code.contains('continue-uri')) rethrow;
        await _auth.sendPasswordResetEmail(email: email.trim());
      }
    } on FirebaseAuthException catch (e) {
      // Don't reveal which addresses have accounts.
      if (e.code == 'user-not-found') return;
      throw AdminAuthException(_common(e) ?? 'Couldn\'t send the email (${e.code}).');
    }
  }

  @override
  Future<void> changePassword({required String current, required String next}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw const AdminAuthException('Your session ended. Sign in again.');
    await _guard(
      () => user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: current)),
      (e) => switch (e.code) {
        'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' => 'Your current password is incorrect.',
        _ => null,
      },
    );
    await _guard(
      () => user.updatePassword(next),
      (e) => e.code == 'weak-password' ? 'Choose a stronger password: at least 8 characters.' : null,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static String? _signInMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'invalid-login-credentials' || 'wrong-password' || 'user-not-found' =>
          'Email or password is incorrect.',
        'user-disabled' => 'This account has been disabled.',
        _ => null,
      };

  static String? _common(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' || 'missing-email' => 'Enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' => 'No internet connection. Check it and try again.',
        _ => null,
      };

  static Future<void> _guard(Future<Object?> Function() run, String? Function(FirebaseAuthException) explain) async {
    try {
      await run();
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(explain(e) ?? _common(e) ?? e.message ?? e.code);
    }
  }
}

/// Hands pages the auth and database to use (real ones in the app, fakes in
/// tests).
class AdminServices extends InheritedWidget {
  const AdminServices({
    super.key,
    required this.auth,
    required this.db,
    required this.projectId,
    required super.child,
  });

  final AdminAuth auth;
  final FirebaseFirestore db;

  /// Shown in the sidebar so it's clear which project's data this is.
  final String projectId;

  static AdminServices of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<AdminServices>();
    assert(services != null, 'No AdminServices above this widget');
    return services!;
  }

  @override
  bool updateShouldNotify(AdminServices oldWidget) =>
      auth != oldWidget.auth || db != oldWidget.db || projectId != oldWidget.projectId;
}
