import 'package:hive_flutter/hive_flutter.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 6)
class AppSettings extends HiveObject {
  @HiveField(0)
  String profileName;

  @HiveField(1)
  String currencySymbol;

  @HiveField(2)
  String currencyCode;

  @HiveField(3)
  bool darkMode;

  @HiveField(4)
  bool notificationsEnabled;

  @HiveField(5)
  String? locale;

  @HiveField(6)
  bool onboardingCompleted;

  @HiveField(7)
  bool appLockEnabled;

  @HiveField(8)
  String? appLockPin;

  @HiveField(9)
  String? appLockPasswordHash;

  @HiveField(10)
  bool budgetWarningsEnabled;

  @HiveField(11)
  bool billRemindersEnabled;

  @HiveField(12)
  bool unusualSpendingEnabled;

  @HiveField(13)
  bool weeklySummaryEnabled;

  /// User-set target for how much to spend per day. Null means the user
  /// hasn't set one yet (screens fall back to an adaptive estimate), which
  /// is also how the one-time setup prompt knows to show itself.
  @HiveField(14)
  double? dailyBudget;

  AppSettings({
    this.profileName = 'Ian',
    this.currencySymbol = 'UGX',
    this.currencyCode = 'UGX',
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.locale,
    this.onboardingCompleted = false,
    this.appLockEnabled = false,
    this.appLockPin,
    this.appLockPasswordHash,
    this.budgetWarningsEnabled = true,
    this.billRemindersEnabled = true,
    this.unusualSpendingEnabled = true,
    this.weeklySummaryEnabled = false,
    this.dailyBudget,
  });
}
