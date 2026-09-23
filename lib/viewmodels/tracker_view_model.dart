import 'package:flutter/foundation.dart' hide Category;

import '../data/money_repository.dart';
import '../models/alert_rule.dart';
import '../models/app_settings.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/income_profile.dart';
import '../models/recurrence_rule.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/wallet.dart';

class TrackerViewModel extends ChangeNotifier {
  final MoneyRepository repo;
  bool initialized = false;
  bool _isUnlocked = false;

  TrackerViewModel(this.repo);

  String? initError;
  bool get hasInitError => initError != null;

  Future<void> init() async {
    try {
      initError = null;
      await repo.init();
      initialized = true;
    } catch (e, st) {
      debugPrint('Error initializing MoneyRepository: $e\n$st');
      initError = 'Failed to load local database: ${e.toString()}';
      initialized = false;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Auth & Onboarding
  // ---------------------------------------------------------------------------
  bool get needsOnboarding => !settings.onboardingCompleted;

  bool get isAppLocked => settings.appLockEnabled && (settings.appLockPin != null && settings.appLockPin!.isNotEmpty);

  bool get isUnlocked => _isUnlocked || !isAppLocked;

  void unlock() {
    _isUnlocked = true;
    notifyListeners();
  }

  void lock() {
    _isUnlocked = false;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final stored = settings.appLockPin;
    if (stored == null || stored.isEmpty) return true;
    return stored == pin;
  }

  Future<void> setAppLock({required String pin, required bool enabled}) async {
    final s = settings;
    s.appLockPin = pin;
    s.appLockEnabled = enabled;
    // also keep hash for compatibility
    s.appLockPasswordHash = pin;
    await updateSettings(s);
    if (!enabled) {
      _isUnlocked = true;
    } else {
      _isUnlocked = false;
    }
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String phone,
    required String email,
    required String incomeSource,
    String? occupation,
    String? pin,
    bool enableLock = false,
    String? currencyCode,
    String? currencySymbol,
    bool? darkMode,
    bool? notificationsEnabled,
    DateTime? dateOfBirth,
    IncomeFrequency? incomeFrequency,
    double? expectedMonthlyIncome,
    IncomeType? incomeType,
    bool? isVariable,
  }) async {
    // Update user
    final user = currentUser;
    user.name = name;
    user.phone = phone;
    user.email = email;
    user.incomeSource = incomeSource;
    user.occupation = occupation;
    user.createdAt = DateTime.now();
    if (dateOfBirth != null) user.dateOfBirth = dateOfBirth;
    if (incomeFrequency != null) user.incomeFrequency = incomeFrequency;
    if (expectedMonthlyIncome != null) user.expectedMonthlyIncome = expectedMonthlyIncome;
    if (incomeType != null) user.incomeType = incomeType;
    if (isVariable != null) user.isVariable = isVariable;
    if (currencyCode != null) {
      user.currencyCode = currencyCode;
      user.currencySymbol = currencySymbol ?? currencyCode;
    }
    if (darkMode != null) user.darkMode = darkMode;
    if (notificationsEnabled != null) user.notificationsEnabled = notificationsEnabled;
    await saveUser(user);

    // Update settings
    final s = settings;
    s.profileName = name;
    s.onboardingCompleted = true;
    if (currencyCode != null) {
      s.currencyCode = currencyCode;
      s.currencySymbol = currencySymbol ?? currencyCode;
    }
    if (darkMode != null) s.darkMode = darkMode;
    if (notificationsEnabled != null) s.notificationsEnabled = notificationsEnabled;
    if (pin != null && pin.isNotEmpty && enableLock) {
      s.appLockPin = pin;
      s.appLockPasswordHash = pin;
      s.appLockEnabled = true;
      _isUnlocked = true; // unlock immediately after onboarding
    } else {
      s.appLockEnabled = false;
    }
    await updateSettings(s);

    notifyListeners();
  }

  Future<void> updateAccountDetails({
    required String name,
    required String phone,
    required String email,
    required String incomeSource,
    String? occupation,
    IncomeFrequency? incomeFrequency,
    double? expectedMonthlyIncome,
    bool? isVariable,
    DateTime? lastPayDate,
  }) async {
    final user = currentUser;
    user.name = name;
    user.phone = phone;
    user.email = email;
    user.incomeSource = incomeSource;
    user.occupation = occupation;
    if (incomeFrequency != null) user.incomeFrequency = incomeFrequency;
    if (expectedMonthlyIncome != null) user.expectedMonthlyIncome = expectedMonthlyIncome;
    if (isVariable != null) {
      user.isVariable = isVariable;
      user.incomeType = isVariable ? IncomeType.variable : (incomeSource == 'salary' ? IncomeType.formal : IncomeType.informal);
    }
    if (lastPayDate != null) user.lastPayDate = lastPayDate;
    await saveUser(user);
    final s = settings;
    s.profileName = name;
    await updateSettings(s);
  }

  // ---------------------------------------------------------------------------
  // Wallets
  // ---------------------------------------------------------------------------
  List<Wallet> get wallets => repo.wallets;

  Wallet walletById(String id) => repo.walletById(id);

  double walletBalance(String id) => repo.walletBalance(id);

  Future<void> saveWallet(Wallet wallet) async {
    await repo.updateWallet(wallet);
    _markDirty();
  }

  Future<void> removeWallet(String id) async {
    await repo.deleteWallet(id);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------
  List<Category> get expenseCategories => repo.expenseCategories;

  List<Category> get incomeCategories => repo.incomeCategories;

  List<Category> get categories => repo.categories;

  List<Category> categoriesOf(TxType type) =>
      repo.categories.where((c) => c.type == type).toList();

  Category? categoryById(String id) => repo.categoryById(id);

  Future<void> addCategory(Category category) async {
    await repo.addCategory(category);
    _markDirty();
  }

  Future<void> updateCategory(Category category) async {
    await repo.addCategory(category); // put is an upsert
    _markDirty();
  }

  Future<void> deleteCategory(String id) async {
    await repo.deleteCategory(id);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------
  List<TxRecord> get transactions => repo.transactions;

  Future<void> addTransaction(TxRecord tx) async {
    await repo.addTransaction(tx);
    await repo.updateWalletBalances();
    _markDirty();
  }

  Future<void> updateTransaction(TxRecord tx) async {
    await repo.updateTransaction(tx);
    await repo.updateWalletBalances();
    _markDirty();
  }

  Future<void> deleteTransaction(String id) async {
    await repo.deleteTransaction(id);
    await repo.updateWalletBalances();
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------------------
  List<Budget> get budgets => repo.budgets;

  Budget? budgetForCategory(String categoryId) =>
      repo.budgetForCategory(categoryId);

  double spentByCategory(DateTime s, DateTime e, String cid) =>
      repo.spentByCategory(s, e, cid);

  double spentTotal(DateTime s, DateTime e) => repo.spentTotal(s, e);

  double incomeTotal(DateTime s, DateTime e) => repo.incomeTotal(s, e);

  Future<void> upsertBudget(Budget budget) async {
    await repo.upsertBudget(budget);
    _markDirty();
  }

  Future<void> deleteBudget(String id) async {
    await repo.deleteBudget(id);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Profile & Settings
  // ---------------------------------------------------------------------------
  User get currentUser => repo.currentUser;

  AppSettings get settings => repo.settings;

  Future<void> saveUser(User user) async {
    await repo.saveUser(user);
    _markDirty();
  }

  Future<void> updateSettings(AppSettings s) async {
    await repo.updateSettings(s);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Savings goals
  // ---------------------------------------------------------------------------
  List<SavingsGoal> get savingsGoals => repo.savingsGoals;

  Future<void> addSavingsGoal(SavingsGoal goal) async {
    await repo.addSavingsGoal(goal);
    _markDirty();
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    await repo.updateSavingsGoal(goal);
    _markDirty();
  }

  Future<void> deleteSavingsGoal(String id) async {
    await repo.deleteSavingsGoal(id);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Bills
  // ---------------------------------------------------------------------------
  List<Bill> get bills => repo.bills;

  Future<void> addBill(Bill bill) async {
    await repo.addBill(bill);
    _markDirty();
  }

  Future<void> updateBill(Bill bill) async {
    await repo.updateBill(bill);
    _markDirty();
  }

  Future<void> deleteBill(String id) async {
    await repo.deleteBill(id);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Debts
  // ---------------------------------------------------------------------------
  List<Debt> get debts => repo.debts;

  Future<void> addDebt(Debt debt) async {
    await repo.addDebt(debt);
    _markDirty();
  }

  Future<void> updateDebt(Debt debt) async {
    await repo.updateDebt(debt);
    _markDirty();
  }

  Future<void> deleteDebt(String id) async {
    await repo.deleteDebt(id);
    _markDirty();
  }

  // ---------------------------------------------------------------------------
  // Recurrence & alerts
  // ---------------------------------------------------------------------------
  List<RecurrenceRule> get recurrenceRules => repo.recurrenceRules;

  List<AlertRule> get alertRules => repo.alertRules;

  Future<void> addRecurrenceRule(RecurrenceRule rule) async {
    await repo.addRecurrenceRule(rule);
    _markDirty();
  }

  Future<void> addAlertRule(AlertRule rule) async {
    await repo.addAlertRule(rule);
    _markDirty();
  }

  Future<void> deleteAlertRule(String id) async {
    await repo.deleteAlertRule(id);
    _markDirty();
  }

  Future<void> clearAll() async {
    for (final t in repo.transactions) {
      await repo.deleteTransaction(t.id);
    }
    await repo.updateWalletBalances();
    _markDirty();
  }

  void _markDirty() {
    notifyListeners();
  }
}