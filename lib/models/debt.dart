import 'package:hive_flutter/hive_flutter.dart';

part 'debt.g.dart';

// Hive persistence rules for every model in lib/models: each `typeId` must be
// unique app-wide, and @HiveField numbers are what's written to disk, so never
// renumber or reuse one. Add new fields with the next unused number (and a
// `defaultValue` so records saved before the field existed still load).
// Regenerate the *.g.dart adapters with `dart run build_runner build`.

/// Which way the money in a [Debt] flows.
@HiveType(typeId: 12)
enum DebtDirection {
  /// Someone else owes the user (money lent out).
  @HiveField(0)
  owedToMe,

  /// The user owes someone else (money borrowed).
  @HiveField(1)
  owedByMe,
}

/// Money lent to or borrowed from a person, tracked until it's settled.
///
/// When the user picks a wallet, the original loan and each repayment are
/// recorded as one-sided transfers tagged `debt:<id>` in [TxRecord.linkId],
/// so they move the wallet balance without counting as income or spending.
@HiveType(typeId: 13)
class Debt extends HiveObject {
  @HiveField(0)
  String id;

  /// Who the debt is with (a person's or business's name).
  @HiveField(1)
  String counterparty;

  /// Amount still outstanding, always positive; [direction] gives the sign.
  /// Each recorded repayment is subtracted from it.
  @HiveField(2)
  double amount;

  @HiveField(3)
  DebtDirection direction;

  /// Optional date the debt should be repaid by. The Debts screen sorts by it
  /// and labels the debt "Overdue" once it has passed.
  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  String? description;

  /// True once [amount] has been repaid down to zero. Settled debts are kept
  /// for history (listed last, dimmed) and left out of the open-debt totals.
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

  /// [amount] from the user's point of view: positive when it's owed to
  /// them, negative when they owe it. Summing these gives net debt position.
  double get signedAmount => direction == DebtDirection.owedToMe ? amount : -amount;
}
