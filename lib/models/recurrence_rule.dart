import 'package:hive_flutter/hive_flutter.dart';

part 'recurrence_rule.g.dart';

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

@HiveType(typeId: 9)
class RecurrenceRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  RecurrenceFrequency frequency;

  @HiveField(2)
  int interval;

  @HiveField(3)
  DateTime? nextRunAt;

  @HiveField(4)
  DateTime? endDate;

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

  bool shouldRunOn(DateTime date) {
    if (nextRunAt == null) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    return !date.isBefore(nextRunAt!);
  }
}
