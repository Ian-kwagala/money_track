import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One tab in [AppBottomNav].
class AppNavItem {
  final String label;
  final IconData icon;

  const AppNavItem({required this.label, required this.icon});
}

/// The raised button in the middle of [AppBottomNav].
class AppNavAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Read by screen readers; defaults to [label].
  final String? semanticLabel;

  const AppNavAction({required this.label, required this.icon, required this.onPressed, this.semanticLabel});
}

/// Bottom navigation bar: a white bar with four line-icon tabs, labels
/// underneath, and a dark round action button in the middle that rises
/// through the bar's top edge.
///
/// Sits flush with the bottom of the screen; its background runs behind the
/// phone's gesture bar / navigation keys while the tabs stay above them.
/// Pages under it should leave [heightOf] free at the bottom.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTabSelected,
    required this.action,
  }) : assert(items.length == 4, 'Two tabs either side of the action');

  /// Exactly four: the first two left of [action], the last two right of it.
  final List<AppNavItem> items;

  /// Index into [items] of the selected tab, or -1 for none.
  final int currentIndex;

  final ValueChanged<int> onTabSelected;
  final AppNavAction action;

  static const barHeight = 72.0;

  /// How far the action button rises above the bar's top edge.
  static const overhang = 12.0;

  static const _buttonSize = 48.0;

  /// Ring in the bar's colour around the button, so it cuts cleanly through
  /// the top border.
  static const _ringWidth = 4.0;

  static const _iconSize = 24.0;
  static const _contentTop = 16.0;
  static const _labelGap = 6.0;

  /// Space the bar covers at the bottom of the screen, gesture area included.
  static double heightOf(BuildContext context) => barHeight + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final colors = _NavColors.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    Widget tab(int i) => Expanded(
          child: _Tab(
            item: items[i],
            selected: currentIndex == i,
            colors: colors,
            onTap: () {
              if (currentIndex != i) HapticFeedback.selectionClick();
              onTabSelected(i);
            },
          ),
        );

    // The button lies inside this widget's bounds (the transparent strip
    // above the bar), so all of it can be tapped.
    return SizedBox(
      height: overhang + barHeight + bottomInset,
      child: Stack(
        children: [
          Positioned.fill(
            top: overhang,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bar,
                border: Border(top: BorderSide(color: colors.border)),
                boxShadow: const [
                  BoxShadow(color: Color(0x2A000000), blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Row(
                  // Full-height tap targets, and every label on one line.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tab(0),
                    tab(1),
                    Expanded(child: _ActionLabel(action: action, colors: colors)),
                    tab(2),
                    tab(3),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _ActionButton(action: action, colors: colors)),
          ),
        ],
      ),
    );
  }
}

/// One tab: icon over label, both fading between the selected and
/// unselected colour.
class _Tab extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final _NavColors colors;
  final VoidCallback onTap;

  const _Tab({required this.item, required this.selected, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? colors.selected : colors.unselected;
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Padding(
          padding: const EdgeInsets.only(top: AppBottomNav._contentTop),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 180),
                builder: (_, c, _) => Icon(item.icon, size: AppBottomNav._iconSize, color: c),
              ),
              const SizedBox(height: AppBottomNav._labelGap),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                // Merged, so the label keeps the app's font.
                style: DefaultTextStyle.of(context).style.merge(_labelStyle(color, bold: selected)),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The action's label, in line with the tab labels; tapping it also runs
/// the action. The icon row is left empty for the raised button.
class _ActionLabel extends StatelessWidget {
  final AppNavAction action;
  final _NavColors colors;

  const _ActionLabel({required this.action, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          action.onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.only(top: AppBottomNav._contentTop),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppBottomNav._iconSize),
              const SizedBox(height: AppBottomNav._labelGap),
              Text(action.label, maxLines: 1, style: _labelStyle(colors.selected, bold: true)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round raised button. Shrinks slightly while pressed. The outer ring
/// is painted in the bar colour, which is what makes it look cut into the
/// bar.
class _ActionButton extends StatefulWidget {
  final AppNavAction action;
  final _NavColors colors;

  const _ActionButton({required this.action, required this.colors});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    const outer = AppBottomNav._buttonSize + AppBottomNav._ringWidth * 2;
    return Semantics(
      button: true,
      label: widget.action.semanticLabel ?? widget.action.label,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: outer,
          height: outer,
          padding: const EdgeInsets.all(AppBottomNav._ringWidth),
          decoration: BoxDecoration(
            color: c.bar,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onHighlightChanged: (down) => setState(() => _pressed = down),
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.action.onPressed();
                },
                child: Icon(widget.action.icon, size: 26, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared label style for tabs and the action label.
TextStyle _labelStyle(Color color, {required bool bold}) => TextStyle(
      fontSize: 11,
      height: 1.2,
      letterSpacing: 0.1,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color,
    );

/// Navigation colors matching the dark translucent theme:
/// Translucent dark navy bottom navigation bar with muted grey-blue inactive icons
/// and glowing white/sky-blue active item highlights.
class _NavColors {
  final Color bar;
  final Color border;
  final Color selected;
  final Color unselected;
  final Color button;
  final Color buttonIcon;

  const _NavColors({
    required this.bar,
    required this.border,
    required this.selected,
    required this.unselected,
    required this.button,
    required this.buttonIcon,
  });

  factory _NavColors.of(BuildContext context) {
    return const _NavColors(
      bar: AppColors.navBarBg,
      border: AppColors.borderLight,
      selected: AppColors.primary,
      unselected: AppColors.navInactive,
      button: AppColors.cardSolid,
      buttonIcon: Colors.white,
    );
  }
}
