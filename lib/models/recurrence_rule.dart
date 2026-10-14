import 'package:hive_flutter/hive_flutter.dart';

part 'recurrence_rule.g.dart';

/// The base unit a [RecurrenceRule] repeats on. Older and narrower than the
/// shared [Frequency] enum that transactions, bills and budgets use now.
@HiveType(typeId: 8)
enum RecurrenceFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  monthly,
  @HiveField(3)
  yearly,
}

/// A schedule for repeating something, e.g. "every 2 weeks until June".
///
/// Rules are stored and synced, and [Bill.recurrenceRuleId] can point at
/// one, but nothing in the app creates or runs them yet. Recurring bills
/// currently use [Bill.frequency] instead.
@HiveType(typeId: 9)
class RecurrenceRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  RecurrenceFrequency frequency;

  /// Repeat every [interval] units of [frequency] (2 + weekly = fortnightly).
  @HiveField(2)
  int interval;

  /// When the rule next fires. Null means it isn't scheduled.
  @HiveField(3)
  DateTime? nextRunAt;

  /// Last date the rule may fire on; null repeats forever.
  @HiveField(4)
  DateTime? endDate;

  /// Whether a due run should post the entry automatically rather than
  /// asking the user first.
  @HiveField(5)
  bool autoPost;

  RecurrenceRule({
    required this.id,
    required this.frequency,
    this.interval = 1,
    this.nextRunAt,
    this.endDate,
    this.autoPost = false,
  });

  /// True when [date] is on or after [nextRunAt] and not past [endDate].
  bool shouldRunOn(DateTime date) {
    if (nextRunAt == null) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    return !date.isBefore(nextRunAt!);
  }
}
