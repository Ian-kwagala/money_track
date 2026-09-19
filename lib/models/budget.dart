import 'package:hive_flutter/hive_flutter.dart';

part 'budget.g.dart';

@HiveType(typeId: 5)
class Budget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String categoryId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime periodStart;

  @HiveField(4)
  bool repeatsMonthly;

  @HiveField(5)
  bool rollover;

  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.periodStart,
    this.repeatsMonthly = true,
    this.rollover = false,
  });
}