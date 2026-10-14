import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

/// The PIN pad shown instead of the app while the app lock is on and the
/// user hasn't unlocked this session (see _RootRouter in main.dart).
///
/// PINs are 4 to 6 digits. A correct PIN calls [TrackerViewModel.unlock],
/// and the root router then swaps this screen for the home screen.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  /// Digits typed so far.
  String _pin = '';
  String? _error;

  /// True while the PIN hash is being checked (it's deliberately slow).
  bool _loading = false;

  /// Handles a numpad key: a digit, 'back' (delete last digit) or 'check'
  /// (verify).
  void _onKey(String key) {
    if (key == 'check') {
      _verify();
      return;
    }
    setState(() {
      _error = null;
      if (key == 'back') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 6) {
        _pin += key;
      }
    });
    if (_pin.length == 4) {
      // Intentionally empty: there's no auto-verify at 4 digits, because the
      // PIN may be up to 6 long. The user taps Unlock or the check key.
    }
  }

  Future<void> _verify() async {
    if (_pin.isEmpty) return;
    setState(() => _loading = true);
    final vm = context.read<TrackerViewModel>();
    final ok = await vm.verifyPin(_pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      vm.unlock();
    } else {
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final name = vm.settings.profileName;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tighter spacing and smaller keys on short screens, so the
            // numpad fits without scrolling.
            final isSmall = constraints.maxHeight < 700;
            return Column(
              children: [
                SizedBox(height: isSmall ? 20 : 40),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 32),
                ),
                SizedBox(height: isSmall ? 12 : 20),
                Text('Hi $name 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Enter your PIN to view your data', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(height: isSmall ? 16 : 28),
                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: filled ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: filled ? AppColors.primary : AppColors.divider, width: 1.5),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                // Only four dots are drawn, so for a 5th or 6th digit show a
                // "5/6" counter instead.
                if (_pin.length > 4)
                  Text('${_pin.length}/6', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
                const Spacer(),
                // Numpad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _LockNumpad(onKey: _onKey, isSmall: isSmall),
                ),
                SizedBox(height: isSmall ? 12 : 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _pin.length >= 4 && !_loading ? _verify : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _showForgotDialog(context),
                  child: const Text('Forgot PIN?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  /// There's no in-app PIN reset yet; this only explains the options.
  void _showForgotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset PIN'),
        content: const Text('To reset your PIN, you will need to verify your phone number. For now, you can clear app data or reinstall. Contact support if needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}

/// 3x4 keypad: digits, backspace and a check (verify) key. Reports presses
/// through [onKey].
class _LockNumpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final bool isSmall;
  const _LockNumpad({required this.onKey, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {IconData? icon, VoidCallback? tap}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: GestureDetector(
            onTap: tap ?? () => onKey(label),
            child: Container(
              height: isSmall ? 56 : 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: AppColors.textPrimary, size: 20)
                    : Text(label, style: TextStyle(fontSize: isSmall ? 20 : 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [key('1'), key('2'), key('3')]),
        Row(children: [key('4'), key('5'), key('6')]),
        Row(children: [key('7'), key('8'), key('9')]),
        Row(children: [key('', icon: Icons.backspace_outlined, tap: () => onKey('back')), key('0'), key('', icon: Icons.check, tap: () => onKey('check'))]),
      ],
    );
  }
}
