import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

class SeedData {
  static const defaultCategoryColors = <String, Color>{
    // spec-matched pastel tints -> solid pairs
    'restaurant': Color(0xFFEA580C), // Food orange
    'directions_bus': Color(0xFF3B82F6), // Transport blue
    'house': Color(0xFF8B5CF6), // Rent purple
    'bolt': Color(0xFFEAB308), // Electricity yellow
    'water_drop': Color(0xFF0EA5E9), // Water blue
    'local_gas_station': Color(0xFFDC2626), // Fuel red
    'sanitary': Color(0xFF14B8A6), // Sanitary teal sparkles
    'favorite': Color(0xFF16A34A), // Health green
    'music_note': Color(0xFFEC4899), // Entertainment pink
    'local_cafe': Color(0xFFEA580C), // Meals Out coffee orange
    'phone_iphone': Color(0xFF84CC16), // Airtime yellow-green
    'school': Color(0xFF7C3AED), // School Fees purple
  };

  static List<Category> expenseCategories() {
    final defs = <(String, String, Color)>[
      ('Food', 'restaurant', Color(0xFFEA580C)),
      ('Transport', 'directions_bus', Color(0xFF3B82F6)),
      ('Rent', 'house', Color(0xFF8B5CF6)),
      ('Electricity', 'bolt', Color(0xFFEAB308)),
      ('Water', 'water_drop', Color(0xFF0EA5E9)),
      ('Fuel', 'local_gas_station', Color(0xFFDC2626)),
      ('Sanitary', 'sanitary', Color(0xFF14B8A6)),
      ('Health', 'favorite', Color(0xFF16A34A)),
      ('Entertainment', 'music_note', Color(0xFFEC4899)),
      ('Meals Out', 'local_cafe', Color(0xFFF97316)),
      ('Airtime & Data', 'phone_iphone', Color(0xFF84CC16)),
      ('School Fees', 'school', Color(0xFF7C3AED)),
    ];
    return defs
        .map((d) => Category(
              id: 'cat_expense_${d.$1.toLowerCase().replaceAll(' ', '_').replaceAll('&', 'and')}',
              name: d.$1,
              icon: d.$2,
              color: d.$3.toARGB32(),
              type: TxType.expense,
              isBuiltIn: true,
            ))
        .toList();
  }

  static List<Category> incomeCategories() {
    final defs = <(String, String)>[
      ('Salary', 'payments'),
      ('Business', 'work'),
      ('Side Hustle', 'attach_money'),
      ('Savings', 'savings'),
      ('Other', 'currency_exchange'),
    ];
    return defs
        .map((d) => Category(
              id: 'cat_income_${d.$1.toLowerCase().replaceAll(' ', '_')}',
              name: d.$1,
              icon: d.$2,
              color: _pickColor(d.$2),
              type: TxType.income,
              isBuiltIn: true,
            ))
        .toList();
  }

  static int _pickColor(String icon) {
    return (defaultCategoryColors[icon] ?? const Color(0xFF0B8457)).toARGB32();
  }

  static List<Wallet> wallets() {
    // No demo balances - user sets during onboarding
    return [
      Wallet(
        id: 'wallet_mtn',
        name: 'MTN Mobile Money',
        type: WalletType.mobileMoney,
        icon: 'mobile',
        color: const Color(0xFFFFCC00).toARGB32(),
        openingBalance: 0,
        currentBalance: 0,
      ),
      Wallet(
        id: 'wallet_airtel',
        name: 'Airtel Money',
        type: WalletType.mobileMoney,
        icon: 'mobile',
        color: const Color(0xFFED1C24).toARGB32(),
        openingBalance: 0,
        currentBalance: 0,
      ),
      Wallet(
        id: 'wallet_cash',
        name: 'Cash',
        type: WalletType.cash,
        icon: 'cash',
        color: const Color(0xFF16A34A).toARGB32(),
        openingBalance: 0,
        currentBalance: 0,
      ),
      Wallet(
        id: 'wallet_bank',
        name: 'Bank',
        type: WalletType.bank,
        icon: 'bank',
        color: const Color(0xFF0B8457).toARGB32(),
        openingBalance: 0,
        currentBalance: 0,
      ),
    ];
  }

  static List<Budget> budgets() {
    // No demo budgets - user creates their own after onboarding
    return [];
  }

  static AppSettings settings() => AppSettings();
}
