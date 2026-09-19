import 'package:hive_flutter/hive_flutter.dart';

part 'alert_rule.g.dart';

@HiveType(typeId: 14)
enum AlertType {
  @HiveField(0)
  budgetWarning,
  @HiveField(1)
  lowBalance,
  @HiveField(2)
  unusualSpending,
  @HiveField(3)
  goalPace,
  @HiveField(4)
  dueDate,
}

@HiveType(typeId: 15)
class AlertRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  AlertType type;

  @HiveField(2)
  String targetId;

  @HiveField(3)
  double threshold;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  String? message;

  @HiveField(6)
  DateTime createdAt;

  AlertRule({
    required this.id,
    required this.type,
    required this.targetId,
    this.threshold = 80,
    this.isActive = true,
    this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
