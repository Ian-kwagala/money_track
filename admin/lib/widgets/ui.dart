import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// The MoneyTrack logo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/logo.png', width: size, height: size, filterQuality: FilterQuality.medium),
      );
}

/// Title, a line of context, and the page's main actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.leading});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// E.g. a back link above the title.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 12,
        spacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(height: 6)],
              Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: text.bodyMedium?.copyWith(color: AdminColors.muted)),
              ],
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// A small rounded label, e.g. "Live" or "Warning".
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, required this.background, this.icon});

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const Pill.neutral({super.key, required this.label, this.icon})
      : color = AdminColors.muted,
        background = const Color(0xFFF1F4F8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A round avatar with someone's initials, coloured by their name so the
/// same person always gets the same colour.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  static const _palette = [
    (AdminColors.green, AdminColors.greenSoft),
    (AdminColors.info, AdminColors.infoSoft),
    (AdminColors.violet, AdminColors.violetSoft),
    (AdminColors.warning, AdminColors.warningSoft),
    (Color(0xFFDB2777), Color(0xFFFCE7F3)),
  ];

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'[\s@._-]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );
  }
}

/// A card with a title row (and optional action) above its content.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final Widget child;

  /// Around [child]; lists usually pass zero to run edge to edge.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Same height with or without an action, so side-by-side panels line up.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(padding: padding ?? const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

/// What a list shows when it has nothing in it.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AdminColors.canvas, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AdminColors.muted),
          ),
          const SizedBox(height: 14),
          Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, style: text.bodySmall?.copyWith(color: AdminColors.muted), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// A coloured box with an icon and a message, e.g. an error or a notice.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, required this.icon, required this.color, required this.background});

  const Notice.error(this.message, {super.key})
      : icon = Icons.error_outline,
        color = AdminColors.danger,
        background = AdminColors.dangerSoft;

  const Notice.success(this.message, {super.key})
      : icon = Icons.check_circle_outline,
        color = AdminColors.green,
        background = AdminColors.greenSoft;

  const Notice.info(this.message, {super.key})
      : icon = Icons.shield_outlined,
        color = AdminColors.warning,
        background = AdminColors.warningSoft;

  final String message;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: AdminColors.text, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small grey caps above a column of a table.
class ColumnLabel extends StatelessWidget {
  const ColumnLabel(this.text, {super.key, this.align = TextAlign.start});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AdminColors.muted),
      );
}

// ---- Formatting -------------------------------------------------------

final _number = NumberFormat.decimalPattern();

String formatCount(num n) => _number.format(n);

/// "UGX 5,000", or just "5,000" without a currency.
String formatMoney(Object? amount, [String? currency]) {
  if (amount is! num) return '-';
  final n = _number.format(amount);
  return currency == null || currency.isEmpty ? n : '$currency $n';
}

DateTime? asDate(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// "Oct 13, 2026".
String formatDate(Object? v) {
  final d = asDate(v);
  return d == null ? '-' : DateFormat.yMMMd().format(d);
}

/// "Oct 13, 2026, 5:05 PM".
String formatDateTime(Object? v) {
  final d = asDate(v);
  return d == null ? '-' : DateFormat.yMMMd().add_jm().format(d);
}

/// "just now", "5 min ago", "3 h ago", "2 days ago", then the date.
String formatAgo(Object? v, {DateTime? now}) {
  final d = asDate(v);
  if (d == null) return 'never';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return diff.inDays == 1 ? 'yesterday' : '${diff.inDays} days ago';
  return DateFormat.yMMMd().format(d);
}

/// Space around a page's content; tighter on phones.
EdgeInsets pagePadding(BuildContext context) {
  final narrow = MediaQuery.sizeOf(context).width < 640;
  return narrow ? const EdgeInsets.fromLTRB(16, 20, 16, 32) : const EdgeInsets.fromLTRB(36, 36, 36, 48);
}
