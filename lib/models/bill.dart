import 'package:hive_flutter/hive_flutter.dart';

import 'frequency.dart';

part 'bill.g.dart';

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

  @HiveField(4)
  String walletId;

  @HiveField(5)
  String? categoryId;

  @HiveField(6)
  int reminderDaysBefore;

  @HiveField(7)
  String? recurrenceRuleId;

  @HiveField(8)
  bool isPaid;

  /// How often this bill recurs. [Frequency.custom] uses [customDays].
  @HiveField(9, defaultValue: Frequency.monthly)
  Frequency frequency;

  /// Interval in days, only used when [frequency] is [Frequency.custom].
  @HiveField(10)
  int? customDays;

  /// Paused bills are excluded from due-date reminders and countdowns.
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

  /// The next date this bill is due, computed from [lastPaidDate] (or
  /// [dueDate] if it has never been paid) advanced by one [frequency] cycle.
  DateTime get nextDueDate {
    if (lastPaidDate == null) return dueDate;
    if (frequency == Frequency.once) return dueDate;
    return frequency.addCycle(lastPaidDate!, customDays: customDays);
  }

  int get daysUntilDue => nextDueDate.difference(DateTime.now()).inDays;

  bool get isOverdue => !isPaused && nextDueDate.isBefore(DateTime.now());
}
