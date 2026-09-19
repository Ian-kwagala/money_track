import 'package:intl/intl.dart';

class MoneyFormat {
  static String money(double amount, {String symbol = 'KSh', int decimals = 0}) {
    final nf = NumberFormat('#,##0${decimals > 0 ? '.${'0' * decimals}' : ''}');
    final formatted = nf.format(amount.abs());
    return '$symbol $formatted';
  }

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

  static String compactSigned(double amount, {String symbol = 'UGX'}) {
    final sign = amount < 0 ? '-' : '';
    return '$sign${compact(amount, symbol: symbol)}';
  }

  static String signed(double amount, {String symbol = 'KSh'}) {
    final sign = amount < 0 ? '-' : '';
    final nf = NumberFormat('#,##0');
    return '$sign$symbol ${nf.format(amount.abs())}';
  }

  static String dayLabel(DateTime d) {
    if (isSameDay(d, DateTime.now())) return 'TODAY';
    if (isSameDay(d, DateTime.now().subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    return d.day.toString().padLeft(2, '0');
  }

  static String fullDay(DateTime d) {
    if (isSameDay(d, DateTime.now())) return 'TODAY';
    if (isSameDay(d, DateTime.now().subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    return DateFormat('EEEE, d MMM yyyy').format(d).toUpperCase();
  }

  static String shortDay(DateTime d) => DateFormat('d MMM').format(d);

  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  static String timeShort(DateTime d) => DateFormat('HH:mm').format(d);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String dayOfWeek(DateTime d) => DateFormat('EEE').format(d);
}
