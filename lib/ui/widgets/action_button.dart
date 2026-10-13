import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

enum _Phase { idle, busy, done }

/// A filled button that answers every press: it sinks slightly while held,
/// gives a light tap of haptics, shows a spinner while [onPressed] runs and
/// a green check when it finishes. Presses while busy are ignored, so a
/// double tap can't save twice.
///
/// [onPressed] returns true when the action happened (shows the check) or
/// false when it didn't, e.g. a validation message was shown instead.
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.doneLabel,
    this.height = 52,
    this.dimmed = false,
    this.color,
    this.doneFor = const Duration(milliseconds: 650),
    this.onDone,
  });

  final String label;
  final IconData? icon;

  /// Null disables the button.
  final Future<bool> Function()? onPressed;

  /// Shown with the check mark; defaults to [label].
  final String? doneLabel;

  final double height;

  /// Looks muted (e.g. the form isn't complete yet) but still responds, so
  /// tapping it can explain what's missing.
  final bool dimmed;

  final Color? color;

  /// How long the check mark shows before [onDone] runs.
  final Duration doneFor;

  /// Runs after the check mark has shown, e.g. to close a sheet.
  final VoidCallback? onDone;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  _Phase _phase = _Phase.idle;
  bool _held = false;

  /// The spinner only appears if the action takes a moment, so quick ones
  /// (or ones that hand over to a dialog) don't flicker.
  bool _spinnerShown = false;

  Future<void> _run() async {
    if (_phase != _Phase.idle || widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _phase = _Phase.busy;
      _spinnerShown = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted && _phase == _Phase.busy) setState(() => _spinnerShown = true);
    });
    var ok = false;
    try {
      ok = await widget.onPressed!();
    } catch (e) {
      debugPrint('ActionButton action failed: $e');
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.done);
    await Future<void>.delayed(widget.doneFor);
    if (!mounted) return;
    widget.onDone?.call();
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = widget.color ?? AppColors.primary;
    final Color background;
    if (_phase == _Phase.done) {
      background = AppColors.success;
    } else if (!enabled) {
      background = AppColors.mutedForeground.withValues(alpha: 0.35);
    } else if (widget.dimmed) {
      background = base.withValues(alpha: 0.45);
    } else {
      background = base;
    }
    final textStyle = (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: Colors.white, fontSize: widget.height < 46 ? 14 : 15, fontWeight: FontWeight.w700);

    final phase = _phase == _Phase.busy && !_spinnerShown ? _Phase.idle : _phase;
    final Widget content = switch (phase) {
      _Phase.busy => const SizedBox(
          key: ValueKey('busy'),
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
        ),
      _Phase.done => Row(
          key: const ValueKey('done'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.doneLabel ?? widget.label, style: textStyle, overflow: TextOverflow.ellipsis)),
          ],
        ),
      _Phase.idle => Row(
          key: const ValueKey('idle'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(widget.label, style: textStyle, overflow: TextOverflow.ellipsis)),
          ],
        ),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: _phase == _Phase.busy ? '${widget.label}, working' : null,
      child: AnimatedScale(
        scale: _held && _phase == _Phase.idle ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: background),
          duration: const Duration(milliseconds: 220),
          builder: (context, color, child) => Material(
            color: color,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            elevation: _held ? 0 : 1,
            shadowColor: base.withValues(alpha: 0.4),
            child: child,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            onTap: enabled ? _run : null,
            onHighlightChanged: (down) => setState(() => _held = down),
            child: SizedBox(
              height: widget.height,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(anim), child: child),
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
