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
    await repo.updateWalletBalances();
    _markDirty();
  }

  /// Sets what the wallet holds *right now*. The opening balance is
  /// back-calculated so existing transactions aren't counted twice.
  Future<void> setWalletBalance(Wallet wallet, double balance) async {
    final isStored = wallets.any((w) => w.id == wallet.id);
    // Compute before mutating: walletBalance reads the stored opening balance.
    final net = isStored ? repo.walletBalance(wallet.id) - wallet.openingBalance : 0.0;
    wallet.openingBalance = balance - net;
    await saveWallet(wallet);
  }

  /// Number of transactions that touch wallet [id] (either side).
  int transactionCountForWallet(String id) =>
      repo.transactions.where((t) => t.walletId == id || t.toWalletId == id).length;

  /// Deletes a wallet without leaving orphaned records behind:
  /// - its own income/expenses are deleted;
  /// - transfers with another wallet are kept as one-sided records, so the
  ///   *other* wallet's balance doesn't change;
  /// - bills paid from it move to the first remaining wallet.
  Future<void> removeWallet(String id) async {
    final name = walletById(id).name;
    for (final t in repo.transactions) {
      if (t.walletId != id && t.toWalletId != id) continue;
      final otherSide = t.walletId == id ? t.toWalletId : t.walletId;
      if (t.type == TxType.transfer && otherSide != null && otherSide.isNotEmpty) {
        if (t.walletId == id) {
          t.walletId = '';
          if (t.note.isEmpty) t.note = 'Transfer from $name (deleted wallet)';
        } else {
          t.toWalletId = null;
          if (t.note.isEmpty) t.note = 'Transfer to $name (deleted wallet)';
        }
        await repo.updateTransaction(t);
      } else {
        await repo.deleteTransaction(t.id);
      }
    }
    final remaining = wallets.where((w) => w.id != id).toList();
    for (final b in bills.where((b) => b.walletId == id)) {
      b.walletId = remaining.isEmpty ? '' : remaining.first.id;
      await repo.updateBill(b);
    }
    await repo.deleteWallet(id);
    await repo.updateWalletBalances();
    _markDirty();
  }

  /// Records money moving between one wallet and something outside the
  /// wallets (a savings goal or a debt). [intoWallet] = money arrives in the
  /// wallet; otherwise it leaves. Stored as a one-sided transfer so it never
  /// counts as income or spending. See [TxRecord.linkId].
  Future<void> recordLinkedMovement({
    required String linkId,
    required String walletId,
    required double amount,
    required bool intoWallet,
    required String note,
  }) {
    return addTransaction(TxRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: TxType.transfer,
      amount: amount,
      walletId: intoWallet ? '' : walletId,
      toWalletId: intoWallet ? walletId : null,
      note: note,
      dateTime: DateTime.now(),
      linkId: linkId,
    ));
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

  /// Sum of all budget limits scaled to a month (daily/weekly budgets are
  /// converted), so it can be compared against a month's spending.
  double get monthlyBudgetTotal =>
      budgets.fold<double>(0, (sum, b) => sum + b.monthlyEquivalent);

  /// How much the user aims to spend per day: their own daily budget if set,
  /// otherwise an estimate from budgets, then this month's income, then the
  /// current pace. Shared by every screen that shows a daily target.
  double get dailyTarget {
    final own = settings.dailyBudget;
    if (own != null && own > 0) return own;
    final budgetTotal = monthlyBudgetTotal;
    if (budgetTotal > 0) return budgetTotal / 30;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final income = incomeTotal(monthStart, now);
    if (income > 0) return income / 30;
    return spentTotal(monthStart, now) / now.day;
  }

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