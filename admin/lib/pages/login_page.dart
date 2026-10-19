import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';

enum _Mode { signIn, reset, resetSent }

/// Sign-in for admins, with "Forgot password?" to get a reset link by
/// email. Wide screens get a brand panel on the left.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  var _mode = _Mode.signIn;
  var _busy = false;
  var _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _emailLooksValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AdminAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!_emailLooksValid) return setState(() => _error = 'Enter a valid email address.');
    if (_password.text.isEmpty) {
      _passwordFocus.requestFocus();
      return setState(() => _error = 'Enter your password.');
    }
    await _run(() async {
      await AdminServices.of(context).auth.signIn(email: _email.text, password: _password.text);
      TextInput.finishAutofillContext();
    });
  }

  Future<void> _sendReset() async {
    if (!_emailLooksValid) return setState(() => _error = 'Enter the email address of your admin account.');
    await _run(() async {
      await AdminServices.of(context).auth.sendPasswordReset(_email.text);
      if (mounted) setState(() => _mode = _Mode.resetSent);
    });
  }

  void _switchTo(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 960;
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(_mode), child: _form(context, showLogo: !wide)),
                ),
              ),
            ),
          );
          if (!wide) return form;
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: form),
            ],
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context, {required bool showLogo}) {
    final text = Theme.of(context).textTheme;
    final (title, subtitle) = switch (_mode) {
      _Mode.signIn => ('Welcome back', 'Sign in to the MoneyTrack admin console.'),
      _Mode.reset => ('Reset your password', 'Enter your admin email and we\'ll send you a link to choose a new password.'),
      _Mode.resetSent => ('Check your email', 'If ${_email.text.trim()} has an account, a reset link is on its way.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo) ...[
          const Row(children: [BrandMark(size: 40), SizedBox(width: 12), _Wordmark(dark: true)]),
          const SizedBox(height: 36),
        ],
        Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(height: 6),
        Text(subtitle, style: text.bodyMedium?.copyWith(color: AdminColors.muted, height: 1.5)),
        const SizedBox(height: 28),
        if (_error != null) ...[Notice.error(_error!), const SizedBox(height: 16)],
        ...switch (_mode) {
          _Mode.signIn => _signInFields(),
          _Mode.reset => _resetFields(),
          _Mode.resetSent => _sentFields(),
        },
        const SizedBox(height: 32),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AdminColors.muted),
            SizedBox(width: 6),
            Text('Admins only · every look at user data is logged',
                style: TextStyle(fontSize: 12, color: AdminColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _emailField({bool autofocus = false, VoidCallback? onSubmit}) => TextField(
        controller: _email,
        autofocus: autofocus,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        textInputAction: onSubmit == null ? TextInputAction.next : TextInputAction.go,
        onSubmitted: (_) => onSubmit == null ? _passwordFocus.requestFocus() : onSubmit(),
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'you@example.com',
          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
        ),
      );

  Widget _submit(String label, VoidCallback onPressed) => FilledButton(
        onPressed: _busy ? null : onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Text(label),
      );

  List<Widget> _signInFields() => [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _emailField(),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                focusNode: _passwordFocus,
                enabled: !_busy,
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: TextButton(
              onPressed: _busy ? null : () => _switchTo(_Mode.reset),
              child: const Text('Forgot password?'),
            ),
          ),
        ),
        _submit('Sign in', _signIn),
      ];

  List<Widget> _resetFields() => [
        _emailField(autofocus: true, onSubmit: _sendReset),
        const SizedBox(height: 20),
        _submit('Send reset link', _sendReset),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _busy ? null : () => _switchTo(_Mode.signIn),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to sign in'),
        ),
      ];

  List<Widget> _sentFields() => [
        const Notice.success(
          'Open the link in the email to choose a new password, then come back and sign in. '
          'It can take a minute to arrive; check Spam too.',
        ),
        const SizedBox(height: 20),
        _submit('Back to sign in', () {
          _password.clear();
          _switchTo(_Mode.signIn);
        }),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _sendReset,
          child: const Text('Didn\'t get it? Send again'),
        ),
      ];
}

/// "MoneyTrack" with "Admin console" underneath.
class _Wordmark extends StatelessWidget {
  const _Wordmark({this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MoneyTrack',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: dark ? AdminColors.text : Colors.white, letterSpacing: -0.2)),
          Text('Admin console',
              style: TextStyle(fontSize: 12, color: dark ? AdminColors.muted : AdminColors.navyText)),
        ],
      );
}

/// Left half of the wide login: logo, what the console is for, and how
/// user data is protected.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminColors.navy, Color(0xFF26318A)],
        ),
      ),
      child: Stack(
        children: [
          // The logo's rings, large and faint, as a backdrop.
          Positioned(
            right: -120,
            bottom: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 56),
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: 60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.amber.withValues(alpha: 0.6), width: 3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [BrandMark(size: 40), SizedBox(width: 12), _Wordmark()]),
                const Spacer(),
                const Text(
                  'Everything you need\nto run MoneyTrack.',
                  style: TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.8),
                ),
                const SizedBox(height: 16),
                const Text(
                  'See how MoneyTrack is growing, help people with their backed-up data and reach every phone with an announcement.',
                  style: TextStyle(color: AdminColors.navyText, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 36),
                for (final (icon, line) in const [
                  (Icons.insights_rounded, 'Live sign-ups, activity and totals'),
                  (Icons.visibility_outlined, 'Read-only access to user data'),
                  (Icons.fact_check_outlined, 'Every look at a user is audit-logged'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 18, color: AdminColors.amber),
                        ),
                        const SizedBox(width: 14),
                        Text(line, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                const Spacer(),
                Text('© ${DateTime.now().year} MoneyTrack',
                    style: const TextStyle(color: AdminColors.navyText, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
