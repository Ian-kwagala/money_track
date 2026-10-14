import 'package:hive_flutter/hive_flutter.dart';

// The Hive type adapters for the enums below are generated into this file by
// build_runner (`dart run build_runner build`). Re-run it after changing any
// @HiveType / @HiveField annotation here.
part 'income_profile.g.dart';

/// How often a user's income actually lands, distinct from [Frequency]
/// (which describes transaction/bill/budget recurrence).
///
/// Persisted in two places, which constrains how this enum may change:
/// - Hive (local): `typeId: 17` must stay unique across every @HiveType in
///   the app, and each @HiveField index is what's written to disk. Never
///   renumber or reuse an index; give new values the next unused number,
///   otherwise saved profiles load as the wrong frequency.
/// - Cloud sync (`cloud_codec.dart`): values are stored by their *name*, so
///   renaming one makes existing cloud data fall back to [monthly].
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

  /// No fixed schedule (gig work, side hustles, casual jobs). Payday
  /// automation is skipped for this value; see [IncomeFrequencyX.nextDate].
  @HiveField(4)
  irregular,
}

/// Display and scheduling helpers for [IncomeFrequency].
extension IncomeFrequencyX on IncomeFrequency {
  /// Human-readable name shown in pickers and summaries.
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
      // Fixed-length intervals: just add whole days.
      case IncomeFrequency.daily:
        return from.add(const Duration(days: 1));
      case IncomeFrequency.weekly:
        return from.add(const Duration(days: 7));
      case IncomeFrequency.biweekly:
        return from.add(const Duration(days: 14));

      // Same day of the next calendar month. DateTime rolls an overflowing
      // month into the next year (Dec -> Jan), but it also rolls an
      // overflowing day forward: Jan 31 + 1 month becomes Mar 3 (or Mar 2 in
      // a leap year), not Feb 28. Results drift for paydays on the 29th-31st.
      // Note also that this constructor drops the time of day from [from].
      case IncomeFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);

      // Nothing to predict, so callers should not schedule a payday.
      case IncomeFrequency.irregular:
        return null;
    }
  }
}

/// Broad classification of how a user earns, used to tailor budgeting and
/// payday automation.
///
/// Set during onboarding (and when income settings are edited) from the
/// user's answers: [variable] if they say their income varies, otherwise
/// [formal] for a salary and [informal] for any other source.
///
/// The same persistence rules as [IncomeFrequency] apply: `typeId: 18` must
/// stay unique, existing @HiveField indices must never change, and values
/// must not be renamed. Unknown or missing values fall back to [formal].
@HiveType(typeId: 18)
enum IncomeType {
  /// Salaried work with a steady, predictable amount.
  @HiveField(0)
  formal,

  /// A non-salary source (business, casual work, etc.) with a steady amount.
  @HiveField(1)
  informal,

  /// Income whose amount changes from one pay period to the next.
  @HiveField(2)
  variable,
}

/// Display helpers for [IncomeType].
extension IncomeTypeX on IncomeType {
  /// Human-readable name shown in pickers and summaries.
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
