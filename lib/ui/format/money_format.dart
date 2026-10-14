import 'package:intl/intl.dart';

/// Display formatting for amounts and dates, shared by every screen.
///
/// Callers pass the user's currency symbol (`vm.settings.currencySymbol`).
/// The 'KSh' / 'UGX' parameter defaults are only fallbacks.
class MoneyFormat {
  /// "UGX 1,250,000". Always unsigned (uses the absolute value); the caller
  /// shows direction with colour or +/-. See [signed] for a version that
  /// keeps the minus sign.
  static String money(double amount, {String symbol = 'KSh', int decimals = 0}) {
    final nf = NumberFormat('#,##0${decimals > 0 ? '.${'0' * decimals}' : ''}');
    final formatted = nf.format(amount.abs());
    return '$symbol $formatted';
  }

  /// Short form for tight spaces: "UGX 1.5M", "UGX 250k", "UGX 900".
  /// Unsigned, like [money]; one decimal only when it isn't a whole number.
  static String compact(double amount, {String symbol = 'UGX'}) {
    final abs = amount.abs();
    if (abs >= 1000000) {
      final val = abs / 1000000;
      final formatted = val == val.roundToDouble()
          ? val.toStringAsFixed(0)
          : val.toStringAsFixed(1);
      return '$symbol ${formatted}M';
    } else if (abs >= 1000) {
      final val = abs / 1000;
      final formatted = val == val.roundToDouble()
          ? val.toStringAsFixed(0)
          : val.toStringAsFixed(1);
      return '$symbol ${formatted}k';
    }
    return '$symbol ${abs.toStringAsFixed(0)}';
  }

  /// [compact] with a leading "-" for negative amounts ("-UGX 250k").
  static String compactSigned(double amount, {String symbol = 'UGX'}) {
    final sign = amount < 0 ? '-' : '';
    return '$sign${compact(amount, symbol: symbol)}';
  }

  /// Full amount with a leading "-" for negatives, e.g. wallet balances
  /// that can go below zero.
  static String signed(double amount, {String symbol = 'KSh'}) {
    final sign = amount < 0 ? '-' : '';
    final nf = NumberFormat('#,##0');
    return '$sign$symbol ${nf.format(amount.abs())}';
  }

  // Date labels for grouped transaction lists. "TODAY" / "YESTERDAY" replace
  // the date for the two most recent days.

  /// "TODAY", "YESTERDAY", or the two-digit day of the month ("07").
  static String dayLabel(DateTime d) {
    if (isSameDay(d, DateTime.now())) return 'TODAY';
    if (isSameDay(d, DateTime.now().subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    return d.day.toString().padLeft(2, '0');
  }

  /// "TODAY", "YESTERDAY", or e.g. "MONDAY, 5 OCT 2026".
  static String fullDay(DateTime d) {
    if (isSameDay(d, DateTime.now())) return 'TODAY';
    if (isSameDay(d, DateTime.now().subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    return DateFormat('EEEE, d MMM yyyy').format(d).toUpperCase();
  }

  /// "5 Oct"
  static String shortDay(DateTime d) => DateFormat('d MMM').format(d);

  /// "October 2026"
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  /// "2:05 PM"
  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  /// "14:05"
  static String timeShort(DateTime d) => DateFormat('HH:mm').format(d);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Mon"
  static String dayOfWeek(DateTime d) => DateFormat('EEE').format(d);
}
