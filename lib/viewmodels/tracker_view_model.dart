import 'dart:io' as io;

import 'package:flutter/foundation.dart' hide Category;

import '../data/hive_boxes.dart';
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
import '../services/security/pin_hash.dart';

/// The single app-wide state object that every screen reads and writes
/// through.
///
/// Provided at the root of the widget tree (see main.dart); screens get it
/// with `context.watch<TrackerViewModel>()` to rebuild on changes, or
/// `context.read` to call methods. Getters read straight from
/// [MoneyRepository] (Hive), so they're always current. Every write goes to
/// the repository and then calls [notifyListeners] so the UI rebuilds.
///
/// Rule of thumb: any write that can change a wallet's balance (a
/// transaction or wallet change) also calls
/// [MoneyRepository.updateWalletBalances] to refresh the cached
/// [Wallet.currentBalance].
class TrackerViewModel extends ChangeNotifier {
  final MoneyRepository repo;

  /// True once local storage has opened successfully. Screens show a loading
  /// or error state until then.
  bool initialized = false;

  /// Tracks active data loading or refreshing in the background.
  bool _isLoading = false;

  /// Whether the app is actively loading or refreshing data in the foreground.
  /// Used by skeleton loaders to display animated placeholders.
  bool get isLoading => _isLoading;

  /// Sets the loading state and updates listeners.
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Refreshes local storage and cloud sync while temporarily
  /// engaging the skeleton loading state for smooth visual feedback.
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Re-read storage and refresh listeners.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      refreshFromStorage();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Whether the user has entered their PIN this session. Not persisted, so
  /// the app is locked again after every restart.
  bool _isUnlocked = false;

  /// Runs once local storage is open (used to start cloud sync). Not awaited,
  /// so it can never delay the app becoming usable.
  final Future<void> Function()? onReady;

  TrackerViewModel(this.repo, {this.onReady});

  /// Message describing why local storage failed to open, if it did.
  String? initError;
  bool get hasInitError => initError != null;

  /// Re-reads everything from local storage (e.g. after a cloud sync wrote to it).
  void refreshFromStorage() => notifyListeners();

  /// Opens local storage, upgrades any plain-text PIN, then kicks off
  /// [onReady]. Errors are caught and kept in [initError] so the app can show
  /// a retry screen instead of crashing.
  Future<void> init() async {
    try {
      initError = null;
      await repo.init();
      await hashLegacyPin();
      initialized = true;
      onReady?.call().catchError((Object e) => debugPrint('onReady failed: $e'));
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
  /// True for a fresh install, until [completeOnboarding] runs.
  bool get needsOnboarding => !settings.onboardingCompleted;

  /// A PIN has been set (stored as a hash, or in plain text by a version
  /// before 1.0.1 that [hashLegacyPin] hasn't upgraded yet).
  bool get hasPin =>
      PinHash.isHash(settings.appLockPasswordHash) || (settings.appLockPin?.isNotEmpty ?? false);

  /// The lock is switched on *and* there is a PIN to check against.
  bool get isAppLocked => settings.appLockEnabled && hasPin;

  /// Whether the app content may be shown: always true when no lock is set.
  bool get isUnlocked => _isUnlocked || !isAppLocked;

  // unlock() is called by the lock screen after a correct PIN. lock() puts
  // the lock screen back; its only caller is the "Lock now" button in
  // AccountSettingsScreen, which no screen currently opens.
  void unlock() {
    _isUnlocked = true;
    notifyListeners();
  }

  void lock() {
    _isUnlocked = false;
    notifyListeners();
  }

  /// Checks [pin] against the stored hash. If only a legacy plain-text PIN
  /// exists, compares against that and upgrades it to a hash on success.
  /// With no PIN stored at all, any input is accepted.
  Future<bool> verifyPin(String pin) async {
    final s = settings;
    final hash = s.appLockPasswordHash;
    if (PinHash.isHash(hash)) return PinHash.verify(pin, hash!);
    final legacy = s.appLockPin;
    if (legacy == null || legacy.isEmpty) return true;
    final ok = legacy == pin;
    if (ok) await _savePinHash(s, pin);
    return ok;
  }

  /// Sets a new PIN and turns the lock on. Only a salted hash is stored.
  Future<void> setPin(String pin) async {
    final s = settings;
    s.appLockEnabled = true;
    await _savePinHash(s, pin);
    _isUnlocked = false;
    notifyListeners();
  }

  /// Turns the lock on or off, keeping the PIN already set.
  Future<void> setAppLockEnabled(bool enabled) async {
    final s = settings;
    s.appLockEnabled = enabled && hasPin;
    await updateSettings(s);
    _isUnlocked = !s.appLockEnabled;
    notifyListeners();
  }

  /// Versions before 1.0.1 stored the PIN in plain text. Replaces it with a
  /// hash; never stops the app from opening if that fails.
  @visibleForTesting
  Future<void> hashLegacyPin() async {
    final s = settings;
    final legacy = s.appLockPin;
    if (legacy == null || legacy.isEmpty) return;
    try {
      await _savePinHash(s, legacy);
    } catch (e) {
      debugPrint('Could not upgrade the app-lock PIN: $e');
    }
  }

  Future<void> _savePinHash(AppSettings s, String pin) async {
    s.appLockPasswordHash = await PinHash.create(pin);
    s.appLockPin = null;
    await updateSettings(s);
    // Hive appends changes to its file; compacting drops the old copies, so
    // a PIN that used to be stored in plain text isn't left behind on disk.
    await repo.boxFor(HiveBoxes.settings).compact();
  }

  /// Saves everything collected by the onboarding flow to both the [User]
  /// and [AppSettings] records, marks onboarding done, and optionally sets
  /// up the app lock. Optional arguments left null keep their current value.
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
      s.appLockEnabled = true;
      _isUnlocked = true; // unlock immediately after onboarding
      await _savePinHash(s, pin);
    } else {
      s.appLockEnabled = false;
      await updateSettings(s);
    }

    notifyListeners();
  }

  /// Saves edits from AccountSettingsScreen. When [isVariable] is
  /// given, [User.incomeType] is re-derived the same way onboarding does it.
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
  /// Wallets ordered with the most-used and most recently used ones first,
  /// falling back to the original storage order on ties.
  List<Wallet> get wallets => _rankWallets(repo.wallets);

  List<Wallet> _rankWallets(List<Wallet> raw) {
    if (raw.length <= 1) return raw;
    final counts = <String, int>{};
    final lastUsed = <String, DateTime>{};
    for (final t in repo.transactions) {
      if (t.walletId.isNotEmpty) {
        counts[t.walletId] = (counts[t.walletId] ?? 0) + 1;
        final prev = lastUsed[t.walletId];
        if (prev == null || t.dateTime.isAfter(prev)) {
          lastUsed[t.walletId] = t.dateTime;
        }
      }
      final toId = t.toWalletId;
      if (toId != null && toId.isNotEmpty) {
        counts[toId] = (counts[toId] ?? 0) + 1;
        final prev = lastUsed[toId];
        if (prev == null || t.dateTime.isAfter(prev)) {
          lastUsed[toId] = t.dateTime;
        }
      }
    }
    final order = {for (final (i, w) in raw.indexed) w.id: i};
    return [...raw]..sort((a, b) {
        final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
        if (byCount != 0) return byCount;
        final dateA = lastUsed[a.id];
        final dateB = lastUsed[b.id];
        if (dateA != null && dateB != null) {
          final byRecent = dateB.compareTo(dateA);
          if (byRecent != 0) return byRecent;
        } else if (dateB != null) {
          return 1;
        } else if (dateA != null) {
          return -1;
        }
        return order[a.id]!.compareTo(order[b.id]!);
      });
  }

  Wallet walletById(String id) => repo.walletById(id);

  /// Live balance computed from transactions (see MoneyRepository.walletBalance).
  double walletBalance(String id) => repo.walletBalance(id);

  /// Adds or updates a wallet, then refreshes every cached balance.
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
        if (t.receiptPath != null) _deleteReceiptFile(t.receiptPath);
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
  /// Expense categories ordered by usage count and recency, with user-created
  /// categories before unused built-in ones.
  List<Category> get expenseCategories => _rankCategories(repo.expenseCategories);

  /// Income categories ordered by usage count and recency, with user-created
  /// categories before unused built-in ones.
  List<Category> get incomeCategories => _rankCategories(repo.incomeCategories);

  List<Category> get categories => _rankCategories(repo.categories);

  /// Categories for one kind of transaction (income or expense), ranked by
  /// usage count and recency.
  List<Category> categoriesOf(TxType type) =>
      _rankCategories(repo.categories.where((c) => c.type == type).toList());

  List<Category> _rankCategories(List<Category> raw) {
    if (raw.length <= 1) return raw;
    final counts = <String, int>{};
    final lastUsed = <String, DateTime>{};
    for (final t in repo.transactions) {
      if (t.categoryId.isEmpty) continue;
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
      final prev = lastUsed[t.categoryId];
      if (prev == null || t.dateTime.isAfter(prev)) {
        lastUsed[t.categoryId] = t.dateTime;
      }
    }
    final order = {for (final (i, c) in raw.indexed) c.id: i};
    return [...raw]..sort((a, b) {
        final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
        if (byCount != 0) return byCount;
        final dateA = lastUsed[a.id];
        final dateB = lastUsed[b.id];
        if (dateA != null && dateB != null) {
          final byRecent = dateB.compareTo(dateA);
          if (byRecent != 0) return byRecent;
        } else if (dateB != null) {
          return 1;
        } else if (dateA != null) {
          return -1;
        }
        if (a.isBuiltIn != b.isBuiltIn) return a.isBuiltIn ? 1 : -1;
        return order[a.id]!.compareTo(order[b.id]!);
      });
  }

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
  /// Every transaction, newest first.
  List<TxRecord> get transactions => repo.transactions;

  // Transaction writes always refresh wallet balances, since any of them can
  // move money in or out of a wallet.
  Future<void> addTransaction(TxRecord tx) async {
    await repo.addTransaction(tx);
    await repo.updateWalletBalances();
    _markDirty();
  }

  void _deleteReceiptFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final file = io.File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  Future<void> updateTransaction(TxRecord tx) async {
    final oldTx = repo.transactions.where((t) => t.id == tx.id).firstOrNull;
    if (oldTx != null &&
        oldTx.receiptPath != null &&
        oldTx.receiptPath!.isNotEmpty &&
        oldTx.receiptPath != tx.receiptPath) {
      _deleteReceiptFile(oldTx.receiptPath);
    }
    await repo.updateTransaction(tx);
    await repo.updateWalletBalances();
    _markDirty();
  }

  Future<void> deleteTransaction(String id) async {
    final oldTx = repo.transactions.where((t) => t.id == id).firstOrNull;
    if (oldTx?.receiptPath != null) {
      _deleteReceiptFile(oldTx!.receiptPath);
    }
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

  // Totals over a date range (s = start, e = end, both inclusive), counting
  // only income/expense records. Transfers never count.
  double spentByCategory(DateTime s, DateTime e, String cid) =>
      repo.spentByCategory(s, e, cid);

  double spentTotal(DateTime s, DateTime e) => repo.spentTotal(s, e);

  double incomeTotal(DateTime s, DateTime e) => repo.incomeTotal(s, e);

  /// Sum of all budget limits scaled to a month (daily/weekly budgets are
  /// converted), so it can be compared against a month's spending.
  double get monthlyBudgetTotal =>
      budgets.fold<double>(0, (sum, b) => sum + b.monthlyEquivalent);

  /// True when the user has explicitly set an overall monthly spending limit.
  bool get hasCustomMonthlyLimit => (settings.monthlySpendingLimit ?? 0) > 0;

  /// The active monthly spending limit: the user's explicit monthly limit if
  /// set, otherwise the sum of category budgets ([monthlyBudgetTotal]).
  double get effectiveMonthlyLimit =>
      hasCustomMonthlyLimit ? settings.monthlySpendingLimit! : monthlyBudgetTotal;

  /// Saves (or clears, when [limit] is null or <= 0) the user's overall
  /// monthly spending limit in local storage and queues a Firestore sync.
  Future<void> setMonthlySpendingLimit(double? limit) async {
    final s = settings;
    s.monthlySpendingLimit = (limit != null && limit > 0) ? limit : null;
    await updateSettings(s);
  }

  /// Filters [transactions] (newest first) by display title, category name,
  /// or note, case-insensitively.
  List<TxRecord> searchTransactions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return transactions;

    return transactions.where((tx) {
      final cat = categoryById(tx.categoryId);
      final catName = cat?.name ?? '';
      final String title;
      if (tx.isOneSided) {
        title = tx.note.isNotEmpty ? tx.note : (tx.isOneSidedIn ? 'Money in' : 'Money out');
      } else if (tx.type == TxType.transfer) {
        final from = walletById(tx.walletId);
        final to = walletById(tx.toWalletId ?? tx.walletId);
        title = '${from.name} → ${to.name} ${from.name} -> ${to.name}';
      } else {
        title = tx.note.isNotEmpty
            ? tx.note
            : (catName.isNotEmpty ? catName : (tx.type == TxType.income ? 'Income' : 'Expense'));
      }

      return title.toLowerCase().contains(q) ||
          catName.toLowerCase().contains(q) ||
          tx.note.toLowerCase().contains(q);
    }).toList();
  }

  /// How much the user aims to spend per day: their own daily budget if set,
  /// otherwise an estimate from budgets/monthly limit, then this month's
  /// income, then the current pace. Shared by every screen that shows a daily
  /// target.
  double get dailyTarget {
    final own = settings.dailyBudget;
    if (own != null && own > 0) return own;
    final budgetTotal = effectiveMonthlyLimit;
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

  Future<void> deleteRecurrenceRule(String id) async {
    await repo.deleteRecurrenceRule(id);
    _markDirty();
  }

  /// Looks up the [RecurrenceRule] linked to a bill, or null if none exists.
  RecurrenceRule? recurrenceRuleById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final r in recurrenceRules) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> addAlertRule(AlertRule rule) async {
    await repo.addAlertRule(rule);
    _markDirty();
  }

  Future<void> deleteAlertRule(String id) async {
    await repo.deleteAlertRule(id);
    _markDirty();
  }

  /// Deletes every transaction (wallets, categories, budgets, goals and bills
  /// are kept), so balances fall back to the wallets' opening balances.
  Future<void> clearAll() async {
    for (final t in repo.transactions) {
      if (t.receiptPath != null) _deleteReceiptFile(t.receiptPath);
      await repo.deleteTransaction(t.id);
    }
    await repo.updateWalletBalances();
    _markDirty();
  }

  /// Called after every write so listening screens rebuild. Cloud sync picks
  /// up the change separately, by watching the Hive boxes.
  void _markDirty() {
    notifyListeners();
  }
}