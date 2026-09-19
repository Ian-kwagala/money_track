import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart' show IconData, Icons;

part 'wallet.g.dart';

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

extension WalletTypeX on WalletType {
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

@HiveType(typeId: 1)
class Wallet extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  WalletType type;

  @HiveField(3)
  String icon;

  @HiveField(4)
  int color;

  @HiveField(5)
  double openingBalance;

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