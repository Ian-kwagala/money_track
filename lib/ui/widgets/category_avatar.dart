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
    final bg = const Color(0xFF18263E);
    final fg = base;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: _buildIcon(fg),
      ),
    );
  }

  /// Resolves [icon] in order: wallet icon keys, then emoji, then category
  /// icon keys, then [fallback]. The emoji check needs two or more code
  /// points starting above U+2000, so a single-code-point emoji such as
  /// "🍕" falls through to [fallback].
  Widget _buildIcon(Color fg) {
    final known = _iconMap[icon];
    if (known != null) {
      return Icon(known, color: fg, size: size * 0.5);
    }
    if (icon.runes.length > 1 && icon.runes.first > 0x2000) {
      return Text(icon, style: TextStyle(fontSize: size * 0.5));
    }
    final catIcon = Category.materialIcon(icon);
    if (catIcon != Icons.category_outlined) {
      return Icon(catIcon, color: fg, size: size * 0.5);
    }
    return Icon(fallback ?? Icons.category_outlined, color: fg, size: size * 0.5);
  }

  /// The legacy wallet icon keys stored in [Wallet.icon].
  static const _iconMap = <String, IconData>{
    'cash': Icons.payments_outlined,
    'mobile': Icons.smartphone_outlined,
    'card': Icons.credit_card_outlined,
    'bank': Icons.account_balance_outlined,
    'savings': Icons.savings_outlined,
  };
}