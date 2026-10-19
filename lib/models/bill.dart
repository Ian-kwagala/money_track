import 'package:hive_flutter/hive_flutter.dart';

import 'frequency.dart';

part 'bill.g.dart';

/// A bill the user has to pay, such as rent, school fees or electricity,
/// either once or on a repeating schedule.
///
/// Paying a recurring bill doesn't create a new bill. It sets
/// [lastPaidDate], and [nextDueDate] moves on by one [frequency] cycle.
@HiveType(typeId: 11)
class Bill extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double amount;

  /// The bill's first/anchor due date. Once [lastPaidDate] is set, the
  /// upcoming due date is computed from that instead (see [nextDueDate]).
  @HiveField(3)
  DateTime dueDate;

  /// Wallet the bill is normally paid from. Empty if there is none (e.g.
  /// its wallet was deleted and no other wallet was left).
  @HiveField(4)
  String walletId;

  @HiveField(5)
  String? categoryId;

  /// How many days before the due date reminders start.
  @HiveField(6)
  int reminderDaysBefore;

  /// Link to a [RecurrenceRule]. Nothing sets it today, so [isRecurring] is
  /// effectively always false; use [frequency] to tell if a bill repeats.
  @HiveField(7)
  String? recurrenceRuleId;

  /// Legacy "paid" flag. It's set when a bill is paid but never reset for
  /// recurring bills, so don't use it to decide what's due; use
  /// [isDueWithin], [isOverdue] or [isSettled].
  @HiveField(8)
  bool isPaid;

  /// How often this bill recurs. [Frequency.custom] uses [customDays].
  @HiveField(9, defaultValue: Frequency.monthly)
  Frequency frequency;

  /// Interval in days, only used when [frequency] is [Frequency.custom].
  @HiveField(10)
  int? customDays;

  /// Paused bills are excluded from due date reminders and countdowns.
  @HiveField(11, defaultValue: false)
  bool isPaused;

  /// The last time this bill was marked paid. Drives [nextDueDate].
  @HiveField(12)
  DateTime? lastPaidDate;

  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.walletId = '',
    this.categoryId,
    this.reminderDaysBefore = 3,
    this.recurrenceRuleId,
    this.isPaid = false,
    this.frequency = Frequency.monthly,
    this.customDays,
    this.isPaused = false,
    this.lastPaidDate,
  });

  bool get isRecurring => recurrenceRuleId != null && recurrenceRuleId!.isNotEmpty;

  /// The next date this bill is due, computed from [dueDate] advanced in
  /// [frequency] cycles until it falls strictly after [lastPaidDate].
  DateTime get nextDueDate {
    if (lastPaidDate == null || frequency == Frequency.once) return dueDate;
    var next = dueDate;
    while (!next.isAfter(lastPaidDate!)) {
      final advanced = frequency.addCycle(next, customDays: customDays);
      if (advanced.isAtSameMomentAs(next) || advanced.isBefore(next)) break;
      next = advanced;
    }
    return next;
  }

  /// Whole days from today until [nextDueDate]; negative once overdue.
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return dueDay.difference(today).inDays;
  }

  /// A one-off bill that has been paid never comes due again. (Recurring
  /// bills are never "settled"; paying them just moves [nextDueDate].)
  bool get isSettled => frequency == Frequency.once && lastPaidDate != null;

  /// Whether this bill needs paying within [days] days — overdue bills always
  /// count; paused and settled bills never do. This is the single rule every
  /// screen (dashboard, alerts, payday checklist) uses, rather than the
  /// legacy [isPaid] flag, which never resets for recurring bills.
  bool isDueWithin(int days) => !isPaused && !isSettled && daysUntilDue <= days;

  /// Approximate cost per month, for "monthly recurring" totals. One-off and
  /// paused bills contribute nothing.
  double get monthlyEquivalent {
    if (isPaused || frequency == Frequency.once) return 0;
    final days = frequency == Frequency.custom ? customDays : frequency.approxDays;
    if (days == null || days <= 0) return amount;
    return amount * 30 / days;
  }

  /// Past its due date and still needs paying (not paused or settled).
  bool get isOverdue =>!isPaused && !isSettled && nextDueDate.isBefore(DateTime.now());
}
