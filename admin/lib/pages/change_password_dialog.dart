import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Change the signed-in admin's password: current one, then the new one
/// twice. Returns true when it was changed.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.email});

  final String email;

  static Future<bool?> show(BuildContext context, {required String email}) => showDialog<bool>(
        context: context,
        builder: (_) => ChangePasswordDialog(email: email),
      );

  static const minLength = 8;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _show = false;
  var _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// What's wrong with the form, or null when it can be submitted.
  String? get _problem {
    if (_current.text.isEmpty) return 'Enter your current password.';
    if (_next.text.length < ChangePasswordDialog.minLength) {
      return 'The new password needs at least ${ChangePasswordDialog.minLength} characters.';
    }
    if (_next.text == _current.text) return 'The new password must be different from the current one.';
    if (_confirm.text != _next.text) return 'The new passwords don\'t match.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem;
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AdminServices.of(context).auth.changePassword(current: _current.text, next: _next.text);
      if (mounted) Navigator.pop(context, true);
    } on AdminAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailLink() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminServices.of(context).auth.sendPasswordReset(widget.email);
      if (mounted) setState(() => _info = 'We sent a reset link to ${widget.email}.');
    } on AdminAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: _show ? 'Hide passwords' : 'Show passwords',
          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: () => setState(() => _show = !_show),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final strength = _next.text.length;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: Text('Change password', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('For ${widget.email}', style: text.bodyMedium?.copyWith(color: AdminColors.muted)),
              const SizedBox(height: 20),
              if (_error != null) ...[Notice.error(_error!), const SizedBox(height: 16)],
              if (_info != null) ...[Notice.success(_info!), const SizedBox(height: 16)],
              TextField(
                controller: _current,
                autofocus: true,
                enabled: !_busy,
                obscureText: !_show,
                autofillHints: const [AutofillHints.password],
                decoration: _decoration('Current password'),
                onChanged: (_) => setState(() => _error = null),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _emailLink,
                  child: const Text('Forgot it? Email me a reset link'),
                ),
              ),
              TextField(
                controller: _next,
                enabled: !_busy,
                obscureText: !_show,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration('New password'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              _StrengthBar(length: strength),
              const SizedBox(height: 16),
              TextField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: !_show,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration('Confirm new password'),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              const Notice.info(
                'The MoneyTrack app on your phone uses this same account. After changing it, '
                'sign in there again with the new password to keep backing up.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: AdminColors.muted),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : const Text('Change password'),
        ),
      ],
    );
  }
}

/// A thin bar under the new password: red when too short, amber when
/// acceptable, green when long.
class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.length});
  final int length;

  @override
  Widget build(BuildContext context) {
    final (value, color, label) = switch (length) {
      0 => (0.0, AdminColors.border, 'At least ${ChangePasswordDialog.minLength} characters'),
      < ChangePasswordDialog.minLength => (0.3, AdminColors.danger, 'Too short'),
      < 12 => (0.65, AdminColors.warning, 'Okay. Longer is stronger'),
      _ => (1.0, AdminColors.green, 'Strong'),
    };
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              color: color,
              backgroundColor: AdminColors.border,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.muted)),
      ],
    );
  }
}
