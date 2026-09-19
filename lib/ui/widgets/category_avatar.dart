import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../theme/app_theme.dart';

class CategoryAvatar extends StatelessWidget {
  final String icon;
  final Color? color;
  final double size;
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

  static const _iconMap = <String, IconData>{
    'cash': Icons.payments_outlined,
    'mobile': Icons.smartphone_outlined,
    'card': Icons.credit_card_outlined,
    'bank': Icons.account_balance_outlined,
    'savings': Icons.savings_outlined,
  };
}