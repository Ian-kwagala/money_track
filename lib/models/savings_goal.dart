import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';

part 'savings_goal.g.dart';

@HiveType(typeId: 10)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double targetAmount;

  @HiveField(3)
  double currentAmount;

  @HiveField(4)
  DateTime deadline;

  @HiveField(5)
  String icon;

  @HiveField(6)
  int color;

  @HiveField(7)
  String? imagePath;

  @HiveField(8)
  double autoContributionRate;

  @HiveField(9)
  bool roundUpEnabled;

  @HiveField(10)
  DateTime createdAt;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.deadline,
    this.icon = 'savings',
    this.color = 0xFF26A69A,
    this.imagePath,
    this.autoContributionRate = 0,
    this.roundUpEnabled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progressPercent {
    if (targetAmount <= 0) return 0;
    return ((currentAmount / targetAmount) * 100).clamp(0.0, 100.0).toDouble();
  }

  double get remainingAmount => math.max(0.0, targetAmount - currentAmount);

  bool get isOnTrack {
    if (targetAmount <= 0) return true;
    return currentAmount >= (targetAmount * 0.5);
  }
}
