import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cloud/auth_service.dart';
import '../../services/cloud/connectivity_service.dart';
import '../../services/cloud/sync_service.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';

/// Optional sign-in for cloud backup & sync. The app works fully without it.
class CloudAccountScreen extends StatelessWidget {
  const CloudAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final online = context.watch<ConnectivityService>().isOnline;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Backup & sync',
              subtitle: online ? 'Online' : 'Offline — your data is safe on this phone',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: !auth.isAvailable
                  ? const _Note(
                      icon: Icons.cloud_off_outlined,
                      text: 'Cloud backup isn\'t set up in this version of the app. Everything keeps working offline on this phone.',
                    )
                  : sync.status == SyncStatus.needsAccountChoice
                      ? const _AccountConflict()
                      : auth.isSignedIn
                          ? const _SignedIn()
                          : const _SignInForm(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final online = context.watch<ConnectivityService>().isOnline;
    final last = sync.lastSyncedAt;
    final pending = sync.pendingCount;

    final statusText = switch (sync.status) {
      SyncStatus.syncing => 'Syncing…',
      SyncStatus.offline => 'Offline — changes will upload when you\'re back online',
      SyncStatus.error => 'Sync problem: ${sync.lastError ?? 'unknown error'}',
      _ => last == null ? 'Not synced yet' : 'Last synced ${_ago(last)}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          children: [
            Row(children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(auth.email ?? 'Signed in',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(statusText, style: TextStyle(fontSize: 12, color: sync.status == SyncStatus.error ? AppColors.danger : AppColors.mutedForeground)),
            if (pending > 0) ...[
              const SizedBox(height: 4),
              Text('$pending change${pending == 1 ? '' : 's'} waiting to upload',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: (!online || sync.status == SyncStatus.syncing) ? null : sync.syncNow,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync now'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Note(
          icon: Icons.info_outline,
          text: 'Your wallets, transactions, budgets, goals, bills and debts are backed up to your account so you can restore them on a new phone. Your app-lock PIN never leaves this phone. Receipt photos are not uploaded yet. The MoneyTrack team can view backed-up data only to help you when you ask for support.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text('Your data stays on this phone and keeps working offline. Sign back in any time to resume backup.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                ],
              ),
            );
            if (ok == true) await auth.signOut();
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  }
}

class _AccountConflict extends StatelessWidget {
  const _AccountConflict();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.read<SyncService>();
    return _Panel(
      children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(child: Text('Different account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ]),
        const SizedBox(height: 8),
        Text(
          'The data on this phone belongs to another MoneyTrack account. To use ${auth.email ?? 'this account'} here, this phone\'s records must be replaced with that account\'s backup.',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Replace this phone\'s data?'),
                content: const Text('All wallets, transactions, budgets, goals, bills and debts on this phone will be deleted and replaced with the signed-in account\'s backup. This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Replace'),
                  ),
                ],
              ),
            );
            if (ok == true) await sync.replaceLocalWithAccount();
          },
          child: const Text('Replace this phone\'s data'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: sync.cancelAccountSwitch,
          child: const Text('Keep this phone\'s data and sign out'),
        ),
      ],
    );
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        await auth.createAccount(_name.text, _email.text, _password.text);
      } else {
        await auth.signIn(_email.text, _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first, then tap "Forgot password".');
      return;
    }
    try {
      await auth.sendPasswordReset(_email.text);
      messenger.showSnackBar(const SnackBar(content: Text('Password reset email sent')));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().isOnline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Note(
          icon: Icons.cloud_upload_outlined,
          text: 'Optional: sign in to back up your data and restore it on a new phone. MoneyTrack works fully offline without an account.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Sign in')),
            ButtonSegment(value: true, label: Text('Create account')),
          ],
          selected: {_creating},
          onSelectionChanged: (s) => setState(() {
            _creating = s.single;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_creating) ...[
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: _field('Your name')),
          const SizedBox(height: 10),
        ],
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: _field('Email')),
        const SizedBox(height: 10),
        TextField(controller: _password, obscureText: true, decoration: _field('Password'), onSubmitted: (_) => _submit()),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
        if (!online) ...[
          const SizedBox(height: 10),
          const Text('You\'re offline. Signing in needs an internet connection once.',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (_busy || !online) ? null : _submit,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_creating ? 'Create account' : 'Sign in'),
        ),
        if (!_creating)
          TextButton(onPressed: _busy ? null : _resetPassword, child: const Text('Forgot password?')),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.45))),
        ],
      ),
    );
  }
}
