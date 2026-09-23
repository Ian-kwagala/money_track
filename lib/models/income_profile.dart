import 'package:hive_flutter/hive_flutter.dart';

part 'income_profile.g.dart';

/// How often a user's income actually lands, distinct from [Frequency]
/// (which describes transaction/bill/budget recurrence).
@HiveType(typeId: 17)
enum IncomeFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  biweekly,
  @HiveField(3)
  monthly,
  @HiveField(4)
  irregular,
}

extension IncomeFrequencyX on IncomeFrequency {
  String get label {
    switch (this) {
      case IncomeFrequency.daily:
        return 'Daily';
      case IncomeFrequency.weekly:
        return 'Weekly';
      case IncomeFrequency.biweekly:
        return 'Biweekly';
      case IncomeFrequency.monthly:
        return 'Monthly';
      case IncomeFrequency.irregular:
        return 'Irregular';
    }
  }

  /// The next expected pay date after [from], or null for [irregular]
  /// income which has no fixed schedule to automate against.
  DateTime? nextDate(DateTime from) {
    switch (this) {
      case IncomeFrequency.daily:
        return from.add(const Duration(days: 1));
      case IncomeFrequency.weekly:
        return from.add(const Duration(days: 7));
      case IncomeFrequency.biweekly:
        return from.add(const Duration(days: 14));
      case IncomeFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case IncomeFrequency.irregular:
        return null;
    }
  }
}

/// Broad classification of how a user earns, used to tailor budgeting and
/// payday automation.
@HiveType(typeId: 18)
enum IncomeType {
  @HiveField(0)
  formal,
  @HiveField(1)
  informal,
  @HiveField(2)
  variable,
}

extension IncomeTypeX on IncomeType {
  String get label {
    switch (this) {
      case IncomeType.formal:
        return 'Formal';
      case IncomeType.informal:
        return 'Informal';
      case IncomeType.variable:
        return 'Variable';
    }
  }
}
