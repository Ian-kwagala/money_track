import 'package:hive_flutter/hive_flutter.dart';

import 'income_profile.dart';

part 'user.g.dart';

@HiveType(typeId: 7)
class User extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String currencySymbol;

  @HiveField(3)
  String currencyCode;

  @HiveField(4)
  String? locale;

  @HiveField(5)
  bool darkMode;

  @HiveField(6)
  bool notificationsEnabled;

  @HiveField(7)
  String phone;

  @HiveField(8)
  String email;

  @HiveField(9)
  String incomeSource; // 'salary' or 'informal'

  @HiveField(10)
  String? occupation;

  @HiveField(11)
  DateTime? createdAt;

  @HiveField(12)
  DateTime? dateOfBirth;

  /// How often income actually lands (paycheck cadence).
  @HiveField(13, defaultValue: IncomeFrequency.monthly)
  IncomeFrequency incomeFrequency;

  /// The user's expected/average income per month, regardless of
  /// [incomeFrequency] — used to size daily/weekly budget suggestions.
  @HiveField(14, defaultValue: 0.0)
  double expectedMonthlyIncome;

  @HiveField(15, defaultValue: IncomeType.formal)
  IncomeType incomeType;

  /// True when the user's income fluctuates month to month (freelance,
  /// commission, informal trade), even if [incomeType] is formal.
  @HiveField(16, defaultValue: false)
  bool isVariable;

  /// The last confirmed payday. Seeded from [createdAt] until the user's
  /// first confirmed payday, then advanced by [incomeFrequency] each time
  /// they confirm receiving income (see PaydayCheck).
  @HiveField(17)
  DateTime? lastPayDate;

  User({
    this.id = 'default_user',
    this.name = 'Ian',
    this.currencySymbol = 'UGX',
    this.currencyCode = 'UGX',
    this.locale,
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.phone = '',
    this.email = '',
    this.incomeSource = 'salary',
    this.occupation,
    this.createdAt,
    this.dateOfBirth,
    this.incomeFrequency = IncomeFrequency.monthly,
    this.expectedMonthlyIncome = 0.0,
    this.incomeType = IncomeType.formal,
    this.isVariable = false,
    this.lastPayDate,
  });

  /// Age in whole years, or null if [dateOfBirth] hasn't been set.
  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }
}
