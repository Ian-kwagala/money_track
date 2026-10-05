import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    initError = e;
  }
  runApp(AdminApp(initError: initError));
}

const brandGreen = Color(0xFF0B8457);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyTrack Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
        useMaterial3: true,
      ),
      home: initError != null ? _NotConfigured(error: initError!) : const AuthGate(),
    );
  }
}

/// Signed out → login. Signed in without the `admin` custom claim → denied.
/// The claim is set with tools/admin/set-admin.js and enforced by
/// firestore.rules; this check only decides what to show.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return FutureBuilder<IdTokenResult>(
          // Force refresh so a newly granted claim is picked up.
          future: user.getIdTokenResult(true),
          builder: (context, tokenSnap) {
            if (!tokenSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final isAdmin = tokenSnap.data!.claims?['admin'] == true;
            return isAdmin ? AdminShell(user: user) : _NotAdmin(email: user.email ?? '');
          },
        );
      },
    );
  }
}

class _NotAdmin extends StatelessWidget {
  const _NotAdmin({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text('$email is not an admin.', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Grant access with tools/admin/set-admin.js, then sign in again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Firebase is not configured.\n\n$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
