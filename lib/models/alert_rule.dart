import 'package:hive_flutter/hive_flutter.dart';

part 'alert_rule.g.dart';

/// The condition an [AlertRule] watches for.
@HiveType(typeId: 14)
enum AlertType {
  /// Spending is approaching or over a budget's limit.
  @HiveField(0)
  budgetWarning,

  /// A wallet's balance has fallen below a threshold.
  @HiveField(1)
  lowBalance,

  /// Spending is well above the user's usual pattern.
  @HiveField(2)
  unusualSpending,

  /// A savings goal is falling behind the pace needed to hit its deadline.
  @HiveField(3)
  goalPace,

  /// A bill or debt is coming due.
  @HiveField(4)
  dueDate,
}

/// A user-configured alert condition.
///
/// The box and cloud sync for these exist, but no screen creates them yet:
/// the alerts the user currently sees are computed on the fly by
/// AlertsService from the settings toggles in [AppSettings].
@HiveType(typeId: 15)
class AlertRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  AlertType type;

  /// ID of the thing being watched (a budget, wallet, goal or bill,
  /// depending on [type]).
  @HiveField(2)
  String targetId;

  /// When the alert fires. Its unit depends on [type]; the default of 80
  /// suits a budget warning at 80% of the limit.
  @HiveField(3)
  double threshold;

  @HiveField(4)
  bool isActive;

  /// Optional custom text to show instead of the default alert message.
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
