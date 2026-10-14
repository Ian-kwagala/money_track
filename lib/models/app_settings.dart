import 'package:hive_flutter/hive_flutter.dart';

part 'app_settings.g.dart';

/// App-wide preferences. There is a single record, stored under the key
/// `'default'` in the settings box.
///
/// Name, currency, dark mode and notifications are duplicated on [User];
/// MoneyRepository.updateSettings and saveUser copy them across so the two
/// always agree.
@HiveType(typeId: 6)
class AppSettings extends HiveObject {
  /// Display name shown in greetings. 'Ian' is only a placeholder default;
  /// onboarding replaces it.
  @HiveField(0)
  String profileName;

  /// Shown next to amounts, e.g. "UGX 5,000".
  @HiveField(1)
  String currencySymbol;

  /// ISO 4217 currency code.
  @HiveField(2)
  String currencyCode;

  @HiveField(3)
  bool darkMode;

  @HiveField(4)
  bool notificationsEnabled;

  @HiveField(5)
  String? locale;

  /// False until the user finishes onboarding; the app shows onboarding
  /// instead of the home screen while it's false.
  @HiveField(6)
  bool onboardingCompleted;

  /// Whether a PIN is needed to open the app (see LockScreen).
  @HiveField(7)
  bool appLockEnabled;

  /// Plain-text PIN written by versions before 1.0.1. Replaced by
  /// [appLockPasswordHash] at startup; always null after that.
  @HiveField(8)
  String? appLockPin;

  /// The app-lock PIN as a salted hash (see PinHash). Never synced.
  @HiveField(9)
  String? appLockPasswordHash;

  // Toggles from Settings > Notifications. AlertsService checks each one
  // before building that kind of alert.
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
