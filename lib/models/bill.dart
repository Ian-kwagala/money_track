import 'package:hive_flutter/hive_flutter.dart';

part 'bill.g.dart';

@HiveType(typeId: 11)
class Bill extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double amount;

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
  });

  bool get isRecurring => recurrenceRuleId != null && recurrenceRuleId!.isNotEmpty;
}
