import 'package:hive_flutter/hive_flutter.dart';

part 'debt.g.dart';

@HiveType(typeId: 12)
enum DebtDirection {
  @HiveField(0)
  owedToMe,
  @HiveField(1)
  owedByMe,
}

@HiveType(typeId: 13)
class Debt extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String counterparty;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DebtDirection direction;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  String? description;

  @HiveField(6)
  bool isSettled;

  @HiveField(7)
  DateTime createdAt;

  Debt({
    required this.id,
    required this.counterparty,
    required this.amount,
    required this.direction,
    this.dueDate,
    this.description,
    this.isSettled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get signedAmount => direction == DebtDirection.owedToMe ? amount : -amount;
}
