import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';

part 'savings_goal.g.dart';

/// Something the user is saving towards, e.g. "School fees by January".
///
/// Adding or withdrawing money (see goal_funds_dialog.dart) changes
/// [currentAmount] and, when a wallet is chosen, records a one-sided
/// transfer tagged `goal:<id>` in [TxRecord.linkId], so the wallet balance
/// moves without the money counting as spending.
@HiveType(typeId: 10)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double targetAmount;

  /// How much has been put aside so far.
  @HiveField(3)
  double currentAmount;

  @HiveField(4)
  DateTime deadline;

  /// Icon key, mapped to an [IconData] by the goals screen.
  @HiveField(5)
  String icon;

  /// ARGB colour value, used as `Color(color)`.
  @HiveField(6)
  int color;

  // The three fields below are stored and synced but not used by any
  // screen yet; they're reserved for picture goals and automatic saving.
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

  /// Progress from 0 to 100. Capped at 100 even if the user saved more than
  /// the target.
  double get progressPercent {
    if (targetAmount <= 0) return 0;
    return ((currentAmount / targetAmount) * 100).clamp(0.0, 100.0).toDouble();
  }

  /// What's left to save; never negative.
  double get remainingAmount => math.max(0.0, targetAmount - currentAmount);

  bool get isCompleted => targetAmount > 0 && currentAmount >= targetAmount;

  /// The deadline has passed and the target still hasn't been reached.
  bool get isPastDeadline => !isCompleted && DateTime.now().isAfter(deadline);

  /// A rough check: at least half the target is saved. It doesn't look at
  /// how much time is left before [deadline].
  bool get isOnTrack {
    if (targetAmount <= 0) return true;
    return currentAmount >= (targetAmount * 0.5);
  }
}
