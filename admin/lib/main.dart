import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/shell.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    runApp(AdminApp(
      services: (child) => AdminServices(
        auth: FirebaseAdminAuth(),
        db: FirebaseFirestore.instance,
        projectId: app.options.projectId,
        child: child,
      ),
    ));
  } catch (e) {
    runApp(AdminApp(initError: e));
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, this.services, this.initError, this.googleFonts = true});

  /// Wraps the app in its [AdminServices]; null when Firebase failed to start.
  final Widget Function(Widget child)? services;
  final Object? initError;
  final bool googleFonts;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'MoneyTrack Admin',
      debugShowCheckedModeBanner: false,
      theme: adminTheme(googleFonts: googleFonts),
      home: services == null ? _NotConfigured(error: initError) : const AuthGate(),
    );
    return services?.call(app) ?? app;
  }
}

/// Signed out → login. Signed in without the `admin` claim → access denied.
/// The claim is enforced by firestore.rules; this only decides what to show.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Stream<AdminAccount?>? _accounts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accounts ??= AdminServices.of(context).auth.accountChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminAccount?>(
      stream: _accounts,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Message(
            icon: Icons.wifi_off_rounded,
            title: 'Couldn\'t check your access',
            message: 'Check your internet connection, then sign in again.',
            action: FilledButton(
              onPressed: () => AdminServices.of(context).auth.signOut(),
              child: const Text('Back to sign in'),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final account = snap.data;
        if (account == null) return const LoginPage();
        if (!account.isAdmin) {
          return _Message(
            icon: Icons.lock_outline_rounded,
            title: 'This account isn\'t an admin',
            message: '${account.email} can\'t open the dashboard. Ask an existing admin to grant access '
                '(tools/admin/set-admin.js), then sign in again.',
            action: FilledButton(
              onPressed: () => AdminServices.of(context).auth.signOut(),
              child: const Text('Sign out'),
            ),
          );
        }
        return AdminShell(account: account);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 48),
              SizedBox(height: 20),
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
            ],
          ),
        ),
      );
}

/// A centred card for the gate's dead ends (not an admin, offline, setup).
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AdminColors.canvas, borderRadius: BorderRadius.circular(16)),
                      child: Icon(icon, color: AdminColors.muted, size: 26),
                    ),
                    const SizedBox(height: 18),
                    Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(message,
                        style: text.bodyMedium?.copyWith(color: AdminColors.muted, height: 1.5),
                        textAlign: TextAlign.center),
                    if (action != null) ...[const SizedBox(height: 24), action!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    const help = 'Run "flutterfire configure --platforms=web" in the admin folder (see FIREBASE_SETUP.md).';
    final detail = '$error';
    // The placeholder options already say the same thing.
    return _Message(
      icon: Icons.settings_outlined,
      title: 'Firebase isn\'t set up for the dashboard',
      message: detail.contains('flutterfire configure') ? help : '$help\n\n$detail',
    );
  }
}
