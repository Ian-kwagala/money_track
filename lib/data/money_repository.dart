import 'package:hive_flutter/hive_flutter.dart';

import '../models/alert_rule.dart';
import '../models/app_settings.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/frequency.dart';
import '../models/income_profile.dart';
import '../models/recurrence_rule.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import 'hive_boxes.dart';
import 'seed_data.dart';

class MoneyRepository {
  late Box<Wallet> _wallets;
  late Box<Category> _categories;
  late Box<TxRecord> _transactions;
  late Box<Budget> _budgets;
  late Box<AppSettings> _settings;
  late Box<User> _users;
  late Box<SavingsGoal> _savingsGoals;
  late Box<Bill> _bills;
  late Box<Debt> _debts;
  late Box<RecurrenceRule> _recurrenceRules;
  late Box<AlertRule> _alertRules;

  List<Wallet> get wallets => _wallets.values.toList();

  List<Category> get categories => _categories.values.toList();

  List<Category> get expenseCategories =>
      categories.where((c) => c.type == TxType.expense).toList();

  List<Category> get incomeCategories =>
      categories.where((c) => c.type == TxType.income).toList();

  List<TxRecord> get transactions {
    final list = _transactions.values.toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  List<Budget> get budgets => _budgets.values.toList();

  List<User> get users => _users.values.toList();

  List<SavingsGoal> get savingsGoals => _savingsGoals.values.toList();

  List<Bill> get bills => _bills.values.toList();

  List<Debt> get debts => _debts.values.toList();

  List<RecurrenceRule> get recurrenceRules => _recurrenceRules.values.toList();

  List<AlertRule> get alertRules => _alertRules.values.toList();

  AppSettings get settings => _settings.values.isNotEmpty
      ? _settings.values.first
      : AppSettings();

  User get currentUser => _users.values.isNotEmpty
      ? _users.values.first
      : User();

  Wallet walletById(String id) {
    try {
      return _wallets.values.firstWhere((w) => w.id == id);
    } catch (_) {
      if (_wallets.isEmpty) {
        return Wallet(id: id, name: id, type: WalletType.cash);
      }
      return _wallets.values.first;
    }
  }

  Category? categoryById(String id) {
    try {
      return _categories.get(id);
    } catch (_) {
      return null;
    }
  }

  /// [hivePath] is only for tests; the app uses the platform default.
  Future<void> init({String? hivePath}) async {
    if (hivePath != null) {
      Hive.init(hivePath);
    } else {
      await Hive.initFlutter();
    }
    _registerAdapterSafe(WalletTypeAdapter());
    _registerAdapterSafe(WalletAdapter());
    _registerAdapterSafe(TxTypeAdapter());
    _registerAdapterSafe(FrequencyAdapter());
    _registerAdapterSafe(CategoryAdapter());
    _registerAdapterSafe(TxRecordAdapter());
    _registerAdapterSafe(BudgetAdapter());
    _registerAdapterSafe(AppSettingsAdapter());
    _registerAdapterSafe(IncomeFrequencyAdapter());
    _registerAdapterSafe(IncomeTypeAdapter());
    _registerAdapterSafe(UserAdapter());
    _registerAdapterSafe(RecurrenceFrequencyAdapter());
    _registerAdapterSafe(RecurrenceRuleAdapter());
    _registerAdapterSafe(SavingsGoalAdapter());
    _registerAdapterSafe(BillAdapter());
    _registerAdapterSafe(DebtDirectionAdapter());
    _registerAdapterSafe(DebtAdapter());
    _registerAdapterSafe(AlertTypeAdapter());
    _registerAdapterSafe(AlertRuleAdapter());
    await _openBoxes();
    await _seedIfNeeded();
    // Stored balances can be stale (e.g. edited before this fix); always
    // re-derive them from opening balance + transactions on launch.
    await updateWalletBalances();
  }

  void _registerAdapterSafe<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  Future<void> _openBoxes() async {
    _wallets = await Hive.openBox<Wallet>(HiveBoxes.wallets);
    _categories = await Hive.openBox<Category>(HiveBoxes.categories);
    _transactions = await Hive.openBox<TxRecord>(HiveBoxes.transactions);
    _budgets = await Hive.openBox<Budget>(HiveBoxes.budgets);
    _settings = await Hive.openBox<AppSettings>(HiveBoxes.settings);
    _users = await Hive.openBox<User>(HiveBoxes.users);
    _savingsGoals = await Hive.openBox<SavingsGoal>(HiveBoxes.savingsGoals);
    _bills = await Hive.openBox<Bill>(HiveBoxes.bills);
    _debts = await Hive.openBox<Debt>(HiveBoxes.debts);
    _recurrenceRules = await Hive.openBox<RecurrenceRule>(HiveBoxes.recurrenceRules);
    _alertRules = await Hive.openBox<AlertRule>(HiveBoxes.alertRules);
  }

  Future<void> _seedIfNeeded() async {
    final bool isNewInstall = _settings.isEmpty;
    if (_categories.isEmpty) {
      for (final c in SeedData.expenseCategories()) {
        await _categories.put(c.id, c);
      }
      for (final c in SeedData.incomeCategories()) {
        await _categories.put(c.id, c);
      }
    }
    if (_wallets.isEmpty) {
      for (final w in SeedData.wallets()) {
        await _wallets.put(w.id, w);
      }
    }
    if (_budgets.isEmpty) {
      for (final b in SeedData.budgets()) {
        await _budgets.put(b.id, b);
      }
    }
    if (_settings.isEmpty) {
      await _settings.put('default', SeedData.settings());
    } else if (!isNewInstall) {
      // Migration for existing installs before onboarding feature: mark onboarding as completed
      // to avoid forcing old users through onboarding again.
      final existing = _settings.values.first;
      if (!existing.onboardingCompleted) {
        // If old data has transactions/wallets, assume user already onboarded
        if (_transactions.isNotEmpty || _wallets.isNotEmpty) {
          existing.onboardingCompleted = true;
          await _settings.put('default', existing);
        }
      }
    }
    if (_users.isEmpty) {
      await _users.put('default', User());
    }
  }

  // ---------------------------------------------------------------------------
  // Wallets
  // ---------------------------------------------------------------------------
  Future<void> addWallet(Wallet wallet) => _wallets.put(wallet.id, wallet);

  Future<void> updateWallet(Wallet wallet) => _wallets.put(wallet.id, wallet);

  Future<void> deleteWallet(String id) => _wallets.delete(id);

  double walletBalance(String walletId) {
    final opening = _wallets.get(walletId)?.openingBalance ?? 0;
    double net = 0;
    for (final t in _transactions.values) {
      if (t.walletId != walletId && t.toWalletId != walletId) continue;
      if (t.type == TxType.income && t.walletId == walletId) net += t.amount;
      if (t.type == TxType.expense && t.walletId == walletId) net -= t.amount;
      if (t.type == TxType.transfer) {
        if (t.walletId == walletId) net -= t.amount;
        if (t.toWalletId == walletId) net += t.amount;
      }
    }
    return opening + net;
  }

  Future<void> updateWalletBalances() async {
    for (final w in _wallets.values) {
      w.currentBalance = walletBalance(w.id);
      await _wallets.put(w.id, w);
    }
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------
  Future<void> addCategory(Category category) =>
      _categories.put(category.id, category);

  Future<void> deleteCategory(String id) => _categories.delete(id);

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------
  Future<void> addTransaction(TxRecord tx) => _transactions.put(tx.id, tx);

  Future<void> deleteTransaction(String id) async {
    await _transactions.delete(id);
  }

  Future<void> updateTransaction(TxRecord tx) => _transactions.put(tx.id, tx);

  // ---------------------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------------------
  Future<void> upsertBudget(Budget budget) => _budgets.put(budget.id, budget);

  Future<void> deleteBudget(String id) => _budgets.delete(id);

  Budget? budgetForCategory(String categoryId) {
    for (final b in _budgets.values) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  double spentByCategory(DateTime periodStart, DateTime periodEnd, String categoryId) {
    double total = 0;
    for (final t in _transactions.values) {
      if (t.type != TxType.expense) continue;
      if (t.categoryId != categoryId) continue;
      final d = t.dateTime;
      if (d.isBefore(periodStart) || d.isAfter(periodEnd)) continue;
      total += t.amount;
    }
    return total;
  }

  double spentTotal(DateTime periodStart, DateTime periodEnd) {
    double total = 0;
    for (final t in _transactions.values) {
      if (t.type != TxType.expense) continue;
      final d = t.dateTime;
      if (d.isBefore(periodStart) || d.isAfter(periodEnd)) continue;
      total += t.amount;
    }
    return total;
  }

  double incomeTotal(DateTime periodStart, DateTime periodEnd) {
    double total = 0;
    for (final t in _transactions.values) {
      if (t.type != TxType.income) continue;
      final d = t.dateTime;
      if (d.isBefore(periodStart) || d.isAfter(periodEnd)) continue;
      total += t.amount;
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  Future<void> updateSettings(AppSettings settings) async {
    await _settings.put('default', settings);
    if (_users.isNotEmpty) {
      final u = _users.values.first;
      u.name = settings.profileName;
      u.currencySymbol = settings.currencySymbol;
      u.currencyCode = settings.currencyCode;
      u.darkMode = settings.darkMode;
      u.notificationsEnabled = settings.notificationsEnabled;
      await _users.put('default', u);
    }
  }

  Future<void> saveUser(User user) async {
    await _users.put('default', user);
    if (_settings.isNotEmpty) {
      final s = _settings.values.first;
      s.profileName = user.name;
      s.currencySymbol = user.currencySymbol;
      s.currencyCode = user.currencyCode;
      s.darkMode = user.darkMode;
      s.notificationsEnabled = user.notificationsEnabled;
      await _settings.put('default', s);
    }
  }

  Future<void> addSavingsGoal(SavingsGoal goal) => _savingsGoals.put(goal.id, goal);

  Future<void> updateSavingsGoal(SavingsGoal goal) => _savingsGoals.put(goal.id, goal);

  Future<void> deleteSavingsGoal(String id) => _savingsGoals.delete(id);

  Future<void> addBill(Bill bill) => _bills.put(bill.id, bill);

  Future<void> updateBill(Bill bill) => _bills.put(bill.id, bill);

  Future<void> deleteBill(String id) => _bills.delete(id);

  Future<void> addDebt(Debt debt) => _debts.put(debt.id, debt);

  Future<void> updateDebt(Debt debt) => _debts.put(debt.id, debt);

  Future<void> deleteDebt(String id) => _debts.delete(id);

  Future<void> addRecurrenceRule(RecurrenceRule rule) =>
      _recurrenceRules.put(rule.id, rule);

  Future<void> addAlertRule(AlertRule rule) => _alertRules.put(rule.id, rule);

  Future<void> deleteAlertRule(String id) => _alertRules.delete(id);

  /// Puts back the default categories and wallets if a box is empty, e.g.
  /// after switching to a brand-new account that has no backup yet.
  Future<void> restoreDefaultsIfEmpty() async {
    if (_categories.isEmpty) {
      for (final c in [...SeedData.expenseCategories(), ...SeedData.incomeCategories()]) {
        await _categories.put(c.id, c);
      }
    }
    if (_wallets.isEmpty) {
      for (final w in SeedData.wallets()) {
        await _wallets.put(w.id, w);
      }
    }
  }

  /// Raw box access for the cloud sync layer, keyed by [HiveBoxes] name.
  Box boxFor(String name) {
    switch (name) {
      case HiveBoxes.wallets:
        return _wallets;
      case HiveBoxes.categories:
        return _categories;
      case HiveBoxes.transactions:
        return _transactions;
      case HiveBoxes.budgets:
        return _budgets;
      case HiveBoxes.settings:
        return _settings;
      case HiveBoxes.users:
        return _users;
      case HiveBoxes.savingsGoals:
        return _savingsGoals;
      case HiveBoxes.bills:
        return _bills;
      case HiveBoxes.debts:
        return _debts;
      case HiveBoxes.recurrenceRules:
        return _recurrenceRules;
      case HiveBoxes.alertRules:
        return _alertRules;
    }
    throw ArgumentError('Unknown box "$name"');
  }
}