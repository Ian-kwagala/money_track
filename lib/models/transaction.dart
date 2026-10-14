import 'package:hive_flutter/hive_flutter.dart';

import 'frequency.dart';

part 'transaction.g.dart';

/// What a transaction does to the user's money.
@HiveType(typeId: 2)
enum TxType {
  /// Money coming in to [TxRecord.walletId].
  @HiveField(0)
  income,

  /// Money spent from [TxRecord.walletId].
  @HiveField(1)
  expense,

  /// Money moved from [TxRecord.walletId] to [TxRecord.toWalletId]. Doesn't
  /// change the user's total, so it never counts as income or spending.
  @HiveField(2)
  transfer,
}

/// One money movement: an income, an expense or a transfer.
///
/// Wallet balances aren't stored on the transaction. They're derived by
/// adding up every transaction that touches a wallet (see
/// MoneyRepository.walletBalance).
@HiveType(typeId: 4)
class TxRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  TxType type;

  /// Always positive; [type] decides the direction (see [signedAmount]).
  @HiveField(2)
  double amount;

  /// The wallet the money comes from (expense, transfer) or lands in
  /// (income). Empty for a one-sided incoming transfer (see [linkId]).
  @HiveField(3)
  String walletId;

  /// Destination wallet; only set for transfers.
  @HiveField(4)
  String? toWalletId;

  /// The [Category] it's filed under. Empty when none was picked, which is
  /// normal for transfers and goal/debt movements.
  @HiveField(5)
  String categoryId;

  @HiveField(6)
  String note;

  /// When the money moved (chosen by the user, not when it was entered).
  @HiveField(7)
  DateTime dateTime;

  /// Local file path of an attached receipt photo, if any.
  @HiveField(8)
  String? receiptPath;

  @HiveField(9)
  bool isRecurring;

  /// How often this kind of expense/income happens. Defaults to [Frequency.once]
  /// for a plain one-off entry; [isRecurring] is kept in sync for backward
  /// compatibility with existing reads of that field.
  @HiveField(10, defaultValue: Frequency.once)
  Frequency frequency;

  /// Set when this record was created by a savings goal or debt, as
  /// `goal:<id>` or `debt:<id>`. Such records are transfers with only one
  /// wallet side: money out ([walletId] set, [toWalletId] null) or money in
  /// ([walletId] empty, [toWalletId] set). They're managed from the goal/debt
  /// and don't count as income or spending.
  @HiveField(11)
  String? linkId;

  TxRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    this.toWalletId,
    this.categoryId = '',
    this.note = '',
    required this.dateTime,
    this.receiptPath,
    bool? isRecurring,
    this.frequency = Frequency.once,
    this.linkId,
  }) : isRecurring = isRecurring ?? (frequency != Frequency.once && frequency != Frequency.random);

  /// A transfer with only one wallet side: money moved to/from a savings
  /// goal, a debt, or a wallet that has since been deleted.
  bool get isOneSided =>
      type == TxType.transfer && (walletId.isEmpty || toWalletId == null || toWalletId!.isEmpty);

  /// For one-sided transfers: true when money came *into* the wallet.
  bool get isOneSidedIn => isOneSided && walletId.isEmpty;

  /// The wallet a one-sided transfer actually touched.
  String get oneSidedWalletId => isOneSidedIn ? (toWalletId ?? '') : walletId;

  /// The effect on the user's overall total: +amount for income, -amount for
  /// expenses, and 0 for transfers (which only move money between wallets).
  double get signedAmount {
    switch (type) {
      case TxType.income:
        return amount;
      case TxType.expense:
        return -amount;
      case TxType.transfer:
        return 0;
    }
  }
}