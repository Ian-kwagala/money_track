import 'package:hive_flutter/hive_flutter.dart';

import 'frequency.dart';

part 'budget.g.dart';

/// A spending limit for one expense category over a repeating period(a day, a week or a month) as set by the user. 
/// Budgets don't store how much has been spent; that's worked out from the transactions in the current [periodFor] window each time it's needed.
@HiveType(typeId: 5)
class Budget extends HiveObject {
  @HiveField(0)
  String id;

  /// The expense [Category] this limit applies to.
  @HiveField(1)
  String categoryId;

  /// The limit for one period of [frequency].
  @HiveField(2)
  double amount;

  /// The first day of the month the budget was saved in. Nothing reads it
  /// back: the current period is always computed from today's date (see
  /// [periodFor]).
  @HiveField(3)
  DateTime periodStart;

  // Stored and synced, but nothing reads these yet: there's no rollover of
  // unspent money into the next period.
  @HiveField(4)
  bool repeatsMonthly;

  @HiveField(5)
  bool rollover;

  /// The time window this budget's limit applies to. Only [Frequency.daily],
  /// [Frequency.weekly] and [Frequency.monthly] are meaningful here.
  @HiveField(6, defaultValue: Frequency.monthly)
  Frequency frequency;

  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.periodStart,
    this.repeatsMonthly = true,
    this.rollover = false,
    this.frequency = Frequency.monthly,
  });

  /// The limit scaled to a month, so daily/weekly/monthly budgets can be
  /// added together in monthly totals.
  double get monthlyEquivalent {
    switch (frequency) {
      case Frequency.daily:
        return amount * 30;
      case Frequency.weekly:
        return amount * 30 / 7;
      default:
        return amount;
    }
  }

  /// "today" / "this week" / "this month", matching [periodFor].
  String get periodLabel {
    switch (frequency) {
      case Frequency.daily:
        return 'today';
      case Frequency.weekly:
        return 'this week';
      default:
        return 'this month';
    }
  }

  /// The [start, end) window the current cycle covers, relative to [now].
  /// Weeks run Monday to Sunday; months are calendar months.
  (DateTime, DateTime) periodFor(DateTime now) {
    switch (frequency) {
      case Frequency.daily:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case Frequency.weekly:
        // DateTime.weekday is 1 for Monday, so this steps back to Monday.
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case Frequency.monthly:
      default:
        // Month 13 rolls over to January of the next year.
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
    }
  }
}
