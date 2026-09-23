import 'package:hive_flutter/hive_flutter.dart';

part 'frequency.g.dart';

/// Shared recurrence frequency used by transactions, bills and budgets.
/// Not every value is meaningful in every context — e.g. [custom] only
/// applies to bills (paired with a day count), and [random]/[once] only
/// make sense for transactions.
@HiveType(typeId: 16)
enum Frequency {
  @HiveField(0)
  once,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  biweekly,
  @HiveField(4)
  monthly,
  @HiveField(5)
  quarterly,
  @HiveField(6)
  yearly,
  @HiveField(7)
  random,
  @HiveField(8)
  custom,
}

extension FrequencyX on Frequency {
  String get label {
    switch (this) {
      case Frequency.once:
        return 'Once';
      case Frequency.daily:
        return 'Daily';
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.biweekly:
        return 'Biweekly';
      case Frequency.monthly:
        return 'Monthly';
      case Frequency.quarterly:
        return 'Quarterly';
      case Frequency.yearly:
        return 'Yearly';
      case Frequency.random:
        return 'Random';
      case Frequency.custom:
        return 'Custom';
    }
  }

  /// Approximate day count for one cycle. Null where a fixed length
  /// doesn't apply (once / random / custom, which needs its own day count).
  int? get approxDays {
    switch (this) {
      case Frequency.daily:
        return 1;
      case Frequency.weekly:
        return 7;
      case Frequency.biweekly:
        return 14;
      case Frequency.monthly:
        return 30;
      case Frequency.quarterly:
        return 91;
      case Frequency.yearly:
        return 365;
      case Frequency.once:
      case Frequency.random:
      case Frequency.custom:
        return null;
    }
  }

  /// Adds one cycle of this frequency to [from]. For [custom], pass the
  /// bill's own day count in [customDays].
  DateTime addCycle(DateTime from, {int? customDays}) {
    switch (this) {
      case Frequency.daily:
        return from.add(const Duration(days: 1));
      case Frequency.weekly:
        return from.add(const Duration(days: 7));
      case Frequency.biweekly:
        return from.add(const Duration(days: 14));
      case Frequency.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case Frequency.quarterly:
        return DateTime(from.year, from.month + 3, from.day, from.hour, from.minute);
      case Frequency.yearly:
        return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      case Frequency.custom:
        return from.add(Duration(days: customDays ?? 30));
      case Frequency.once:
      case Frequency.random:
        return from;
    }
  }
}
