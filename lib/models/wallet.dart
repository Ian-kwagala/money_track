import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart' show IconData, Icons;

part 'wallet.g.dart';

/// The kind of place money is kept. Decides the wallet's label and icon.
@HiveType(typeId: 0)
enum WalletType {
  @HiveField(0)
  cash,
  @HiveField(1)
  mobileMoney,
  @HiveField(2)
  bank,
  @HiveField(3)
  card,
  @HiveField(4)
  savings,
}

/// Display helpers for [WalletType].
extension WalletTypeX on WalletType {
  /// Human-readable name shown in pickers and lists.
  String get label {
    switch (this) {
      case WalletType.cash:
        return 'Cash';
      case WalletType.mobileMoney:
        return 'Mobile Money';
      case WalletType.bank:
        return 'Bank';
      case WalletType.card:
        return 'Card';
      case WalletType.savings:
        return 'Savings';
    }
  }

  /// The icon screens show for a wallet of this type.
  IconData get icon {
    switch (this) {
      case WalletType.cash:
        return Icons.payments_outlined;
      case WalletType.mobileMoney:
        return Icons.smartphone_outlined;
      case WalletType.bank:
        return Icons.account_balance_outlined;
      case WalletType.card:
        return Icons.credit_card_outlined;
      case WalletType.savings:
        return Icons.savings_outlined;
    }
  }
}

/// A place the user keeps money: a mobile money account, cash, a bank
/// account, etc.
///
/// The balance is never edited directly. It's [openingBalance] plus the
/// effect of every transaction on this wallet; see
/// MoneyRepository.walletBalance.
@HiveType(typeId: 1)
class Wallet extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  WalletType type;

  /// Legacy icon key ('mobile', 'cash', 'bank'). Screens use
  /// [WalletTypeX.icon] instead.
  @HiveField(3)
  String icon;

  /// ARGB colour value, used as `Color(color)`.
  @HiveField(4)
  int color;

  /// The balance before any recorded transactions. Setting a wallet's
  /// balance by hand adjusts this (see TrackerViewModel), so history stays
  /// intact.
  @HiveField(5)
  double openingBalance;

  /// Cached result of MoneyRepository.walletBalance, refreshed whenever
  /// transactions change and on every launch. Read it for display; don't
  /// treat it as the source of truth.
  @HiveField(6)
  double currentBalance;

  Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.icon = '',
    this.color = 0xFF3F51B5,
    this.openingBalance = 0,
    this.currentBalance = 0,
  });
}
