import 'package:hive_flutter/hive_flutter.dart';

import 'frequency.dart';

part 'budget.g.dart';

@HiveType(typeId: 5)
class Budget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String categoryId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime periodStart;

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

  /// The [start, end) window the current cycle covers, relative to [now].
  (DateTime, DateTime) periodFor(DateTime now) {
    switch (frequency) {
      case Frequency.daily:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case Frequency.weekly:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case Frequency.monthly:
      default:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
    }
  }
}
