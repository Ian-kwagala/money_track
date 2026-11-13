import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../theme/app_theme.dart';

/// A round, softly tinted badge with an icon in the middle, used for
/// categories and wallets in lists.
class CategoryAvatar extends StatelessWidget {
  /// An icon key (wallet keys like 'cash', or a category key like
  /// 'restaurant') or an emoji.
  final String icon;

  /// Tint for the icon and its background; the app's primary colour if null.
  final Color? color;

  /// Diameter in logical pixels; the icon is drawn at half of it.
  final double size;

  /// Shown when [icon] isn't recognised.
  final IconData? fallback;

  const CategoryAvatar({
    super.key,
    this.icon = '',
    this.color,
    this.size = 40,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppTheme.primary;
    final bg = base.withValues(alpha: 0.16);
    final fg = base;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: _buildIcon(fg),
      ),
    );
  }

  /// Resolves [icon] in order: wallet icon keys, then category icon keys,
  /// then valid non-CJK emoji, then [fallback].
  Widget _buildIcon(Color fg) {
    final known = _iconMap[icon];
    if (known != null) {
      return Icon(known, color: fg, size: size * 0.5);
    }
    final catIcon = Category.materialIcon(icon);
    if (catIcon != Icons.category_outlined) {
      return Icon(catIcon, color: fg, size: size * 0.5);
    }
    // Only render as text if the string is a genuine supplemental emoji
    // (code point >= 0x1F300) and contains no CJK characters.
    if (icon.isNotEmpty &&
        icon.runes.first >= 0x1F300 &&
        !_cjkPattern.hasMatch(icon)) {
      return Text(icon, style: TextStyle(fontSize: size * 0.5));
    }
    return Icon(fallback ?? Icons.category_outlined, color: fg, size: size * 0.5);
  }

  /// Matches CJK ideographs and fullwidth forms so corrupted icon keys never
  /// render as Chinese text.
  static final _cjkPattern = RegExp(
    r'[\u2E80-\u9FFF\u3400-\u4DBF\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFFEF]',
  );

  /// The legacy wallet icon keys stored in [Wallet.icon].
  static const _iconMap = <String, IconData>{
    'cash': Icons.payments_outlined,
    'mobile': Icons.smartphone_outlined,
    'card': Icons.credit_card_outlined,
    'bank': Icons.account_balance_outlined,
    'savings': Icons.savings_outlined,
  };
}