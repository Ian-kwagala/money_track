import 'dart:math' as math;

import '../models/transaction.dart';

/// The total money across the user's wallets at past moments, worked back
/// from today's balances: the total at time t is today's total minus every
/// change to it recorded after t.
///
/// Working backwards means the chart always ends exactly at the balance
/// the user sees today, even if opening balances were edited along the way.
/// Used by the balance trend card on the Reports screen.
class BalanceHistory {
  BalanceHistory({required this.currentTotal, required Iterable<TxRecord> transactions, this.walletIds})
      : _transactions = transactions.toList();

  /// The total right now (the sum of the wallets' current balances).
  final double currentTotal;

  /// The wallets the total covers. Null when there are no wallets, so the
  /// total is just income minus spending.
  final Set<String>? walletIds;

  final List<TxRecord> _transactions;

  /// How much [t] changed the total. Transfers between two of the wallets
  /// change nothing; money moved to a savings goal, a debt or a deleted
  /// wallet does.
  double change(TxRecord t) {
    final ids = walletIds;
    if (ids == null) return t.signedAmount;
    switch (t.type) {
      case TxType.income:
        return ids.contains(t.walletId) ? t.amount : 0;
      case TxType.expense:
        return ids.contains(t.walletId) ? -t.amount : 0;
      case TxType.transfer:
        return (ids.contains(t.toWalletId) ? t.amount : 0) - (ids.contains(t.walletId) ? t.amount : 0);
    }
  }

  /// The total at [moment]. Scans every transaction, which is fine for the
  /// few dozen chart points it's called for.
  double totalAt(DateTime moment) {
    var later = 0.0;
    for (final t in _transactions) {
      if (t.dateTime.isAfter(moment)) later += change(t);
    }
    return currentTotal - later;
  }
}

/// The span the balance chart covers.
enum TrendRange {
  week('Week', 'last 7 days'),
  month('Month', 'last 30 days'),
  year('Year', 'last 12 months');

  const TrendRange(this.label, this.description);
  final String label;
  final String description;
}

/// One point on the balance chart: the total at [at], labelled [label].
class TrendPoint {
  final DateTime at;
  final String label;
  final double total;

  const TrendPoint(this.at, this.label, this.total);
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// The total at the end of each day (week, month) or month (year) in
/// [range], oldest first. The last point is [now] itself.
List<TrendPoint> balanceTrend(BalanceHistory history, TrendRange range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final points = <TrendPoint>[];
  switch (range) {
    case TrendRange.week:
    case TrendRange.month:
      final days = range == TrendRange.week ? 7 : 30;
      // One point per day, at midnight ending that day (or now, for today).
      // `today.day - i` may go below 1; DateTime rolls it into the previous
      // month.
      for (var i = days - 1; i >= 0; i--) {
        final day = DateTime(today.year, today.month, today.day - i);
        final end = i == 0 ? now : DateTime(day.year, day.month, day.day + 1);
        final label = range == TrendRange.week ? _weekdays[day.weekday - 1] : '${day.day}';
        points.add(TrendPoint(end, label, history.totalAt(end)));
      }
    case TrendRange.year:
      // One point per month, at the start of the following month (or now).
      for (var i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final end = i == 0 ? now : DateTime(month.year, month.month + 1, 1);
        points.add(TrendPoint(end, _months[month.month - 1], history.totalAt(end)));
      }
  }
  return points;
}

/// A y-axis that fits [values] with round gridlines, so the line uses the
/// chart's height whether the balance is UGX 5,000 or UGX 50 million.
({double min, double max, double interval}) niceAxis(Iterable<double> values, {int lines = 4}) {
  var lo = values.reduce(math.min);
  var hi = values.reduce(math.max);
  if (hi == lo) {
    // A flat line sits in the middle rather than on an edge.
    final pad = hi.abs() * 0.1;
    lo -= pad == 0 ? 1000 : pad;
    hi += pad == 0 ? 1000 : pad;
  }
  // Pick a round gridline spacing, then snap the ends outward to multiples
  // of it.
  final step = _niceStep((hi - lo) / lines);
  var min = (lo / step).floorToDouble() * step;
  var max = (hi / step).ceilToDouble() * step;
  // Keep a little room so the line never runs along the very top or bottom.
  if (max - hi < step * 0.1) max += step;
  if (lo - min < step * 0.1 && min != 0) min -= step;
  return (min: min, max: max, interval: step);
}

/// 1, 2, 2.5 or 5 times a power of ten, at least [raw].
double _niceStep(double raw) {
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / magnitude;
  final nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
  return nice * magnitude;
}
