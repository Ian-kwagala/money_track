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

  /// Paused goals are excluded from "on track" nudges but keep their saved
  /// progress.
  @HiveField(11, defaultValue: false)
  bool isPaused;

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
    this.isPaused = false,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progressPercent {
    if (targetAmount <= 0) return 0;
    return ((currentAmount / targetAmount) * 100).clamp(0.0, 100.0).toDouble();
  }

  double get remainingAmount => math.max(0.0, targetAmount - currentAmount);

  bool get isCompleted => targetAmount > 0 && currentAmount >= targetAmount;

  bool get isPastDeadline => !isCompleted && DateTime.now().isAfter(deadline);

  bool get isOnTrack {
    if (targetAmount <= 0) return true;
    return currentAmount >= (targetAmount * 0.5);
  }
}
