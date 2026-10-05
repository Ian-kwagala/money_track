import 'package:hive_flutter/hive_flutter.dart';

import 'frequency.dart';

part 'transaction.g.dart';

@HiveType(typeId: 2)
enum TxType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
  @HiveField(2)
  transfer,
}

@HiveType(typeId: 4)
class TxRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  TxType type;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String walletId;

  @HiveField(4)
  String? toWalletId;

  @HiveField(5)
  String categoryId;

  @HiveField(6)
  String note;

  @HiveField(7)
  DateTime dateTime;

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