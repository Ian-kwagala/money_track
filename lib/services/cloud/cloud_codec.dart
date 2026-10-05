import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/hive_boxes.dart';
import '../../models/alert_rule.dart';
import '../../models/app_settings.dart';
import '../../models/bill.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/debt.dart';
import '../../models/frequency.dart';
import '../../models/income_profile.dart';
import '../../models/recurrence_rule.dart';
import '../../models/savings_goal.dart';
import '../../models/transaction.dart';
import '../../models/user.dart';
import '../../models/wallet.dart';

/// Converts Hive models to/from the plain maps stored in Firestore.
///
/// Firestore collection names are the Hive box names, so every synced box
/// maps 1:1 onto `users/{uid}/{boxName}/{recordKey}`.
///
/// When adding a field to a model, add it to both [encode] and [decode]
/// here, or it will silently not sync.
class CloudCodec {
  static const syncedBoxes = <String>[
    HiveBoxes.wallets,
    HiveBoxes.categories,
    HiveBoxes.transactions,
    HiveBoxes.budgets,
    HiveBoxes.settings,
    HiveBoxes.users,
    HiveBoxes.savingsGoals,
    HiveBoxes.bills,
    HiveBoxes.debts,
    HiveBoxes.recurrenceRules,
    HiveBoxes.alertRules,
  ];

  static Map<String, dynamic> encode(String box, Object value) {
    switch (box) {
      case HiveBoxes.wallets:
        final w = value as Wallet;
        return {
          'id': w.id,
          'name': w.name,
          'type': w.type.name,
          'icon': w.icon,
          'color': w.color,
          'openingBalance': w.openingBalance,
          'currentBalance': w.currentBalance,
        };
      case HiveBoxes.categories:
        final c = value as Category;
        return {
          'id': c.id,
          'name': c.name,
          'icon': c.icon,
          'color': c.color,
          'type': c.type.name,
          'parentCategoryId': c.parentCategoryId,
          'isBuiltIn': c.isBuiltIn,
          'frequency': c.frequency,
        };
      case HiveBoxes.transactions:
        final t = value as TxRecord;
        return {
          'id': t.id,
          'type': t.type.name,
          'amount': t.amount,
          'walletId': t.walletId,
          'toWalletId': t.toWalletId,
          'categoryId': t.categoryId,
          'note': t.note,
          'dateTime': _ts(t.dateTime),
          'receiptPath': t.receiptPath,
          'isRecurring': t.isRecurring,
          'frequency': t.frequency.name,
        };
      case HiveBoxes.budgets:
        final b = value as Budget;
        return {
          'id': b.id,
          'categoryId': b.categoryId,
          'amount': b.amount,
          'periodStart': _ts(b.periodStart),
          'repeatsMonthly': b.repeatsMonthly,
          'rollover': b.rollover,
          'frequency': b.frequency.name,
        };
      case HiveBoxes.settings:
        final s = value as AppSettings;
        // appLockEnabled / appLockPin / appLockPasswordHash are deliberately
        // NOT synced: they protect this device and must never leave it.
        return {
          'profileName': s.profileName,
          'currencySymbol': s.currencySymbol,
          'currencyCode': s.currencyCode,
          'darkMode': s.darkMode,
          'notificationsEnabled': s.notificationsEnabled,
          'locale': s.locale,
          'onboardingCompleted': s.onboardingCompleted,
          'budgetWarningsEnabled': s.budgetWarningsEnabled,
          'billRemindersEnabled': s.billRemindersEnabled,
          'unusualSpendingEnabled': s.unusualSpendingEnabled,
          'weeklySummaryEnabled': s.weeklySummaryEnabled,
          'dailyBudget': s.dailyBudget,
        };
      case HiveBoxes.users:
        final u = value as User;
        return {
          'id': u.id,
          'name': u.name,
          'currencySymbol': u.currencySymbol,
          'currencyCode': u.currencyCode,
          'locale': u.locale,
          'darkMode': u.darkMode,
          'notificationsEnabled': u.notificationsEnabled,
          'phone': u.phone,
          'email': u.email,
          'incomeSource': u.incomeSource,
          'occupation': u.occupation,
          'createdAt': _ts(u.createdAt),
          'dateOfBirth': _ts(u.dateOfBirth),
          'incomeFrequency': u.incomeFrequency.name,
          'expectedMonthlyIncome': u.expectedMonthlyIncome,
          'incomeType': u.incomeType.name,
          'isVariable': u.isVariable,
          'lastPayDate': _ts(u.lastPayDate),
        };
      case HiveBoxes.savingsGoals:
        final g = value as SavingsGoal;
        return {
          'id': g.id,
          'name': g.name,
          'targetAmount': g.targetAmount,
          'currentAmount': g.currentAmount,
          'deadline': _ts(g.deadline),
          'icon': g.icon,
          'color': g.color,
          'imagePath': g.imagePath,
          'autoContributionRate': g.autoContributionRate,
          'roundUpEnabled': g.roundUpEnabled,
          'createdAt': _ts(g.createdAt),
          'isPaused': g.isPaused,
        };
      case HiveBoxes.bills:
        final b = value as Bill;
        return {
          'id': b.id,
          'name': b.name,
          'amount': b.amount,
          'dueDate': _ts(b.dueDate),
          'walletId': b.walletId,
          'categoryId': b.categoryId,
          'reminderDaysBefore': b.reminderDaysBefore,
          'recurrenceRuleId': b.recurrenceRuleId,
          'isPaid': b.isPaid,
          'frequency': b.frequency.name,
          'customDays': b.customDays,
          'isPaused': b.isPaused,
          'lastPaidDate': _ts(b.lastPaidDate),
        };
      case HiveBoxes.debts:
        final d = value as Debt;
        return {
          'id': d.id,
          'counterparty': d.counterparty,
          'amount': d.amount,
          'direction': d.direction.name,
          'dueDate': _ts(d.dueDate),
          'description': d.description,
          'isSettled': d.isSettled,
          'createdAt': _ts(d.createdAt),
        };
      case HiveBoxes.recurrenceRules:
        final r = value as RecurrenceRule;
        return {
          'id': r.id,
          'frequency': r.frequency.name,
          'interval': r.interval,
          'nextRunAt': _ts(r.nextRunAt),
          'endDate': _ts(r.endDate),
          'autoPost': r.autoPost,
        };
      case HiveBoxes.alertRules:
        final a = value as AlertRule;
        return {
          'id': a.id,
          'type': a.type.name,
          'targetId': a.targetId,
          'threshold': a.threshold,
          'isActive': a.isActive,
          'message': a.message,
          'createdAt': _ts(a.createdAt),
        };
    }
    throw ArgumentError('Box "$box" is not synced');
  }

  /// [existing] is the record currently stored locally under the same key,
  /// if any. Settings use it to keep device-only fields (the app lock).
  static Object decode(String box, Map<String, dynamic> m, {Object? existing}) {
    switch (box) {
      case HiveBoxes.wallets:
        return Wallet(
          id: _str(m['id']),
          name: _str(m['name']),
          type: _enum(WalletType.values, m['type'], WalletType.cash),
          icon: _str(m['icon']),
          color: _int(m['color'], 0xFF3F51B5),
          openingBalance: _dbl(m['openingBalance']),
          currentBalance: _dbl(m['currentBalance']),
        );
      case HiveBoxes.categories:
        return Category(
          id: _str(m['id']),
          name: _str(m['name']),
          icon: _str(m['icon']),
          color: _int(m['color'], 0xFF42A5F5),
          type: _enum(TxType.values, m['type'], TxType.expense),
          parentCategoryId: m['parentCategoryId'] as String?,
          isBuiltIn: m['isBuiltIn'] == true,
          frequency: _str(m['frequency'], 'monthly'),
        );
      case HiveBoxes.transactions:
        return TxRecord(
          id: _str(m['id']),
          type: _enum(TxType.values, m['type'], TxType.expense),
          amount: _dbl(m['amount']),
          walletId: _str(m['walletId']),
          toWalletId: m['toWalletId'] as String?,
          categoryId: _str(m['categoryId']),
          note: _str(m['note']),
          dateTime: _date(m['dateTime']) ?? DateTime.now(),
          receiptPath: m['receiptPath'] as String?,
          isRecurring: m['isRecurring'] as bool?,
          frequency: _enum(Frequency.values, m['frequency'], Frequency.once),
        );
      case HiveBoxes.budgets:
        return Budget(
          id: _str(m['id']),
          categoryId: _str(m['categoryId']),
          amount: _dbl(m['amount']),
          periodStart: _date(m['periodStart']) ?? DateTime.now(),
          repeatsMonthly: m['repeatsMonthly'] != false,
          rollover: m['rollover'] == true,
          frequency: _enum(Frequency.values, m['frequency'], Frequency.monthly),
        );
      case HiveBoxes.settings:
        final s = existing is AppSettings ? existing : AppSettings();
        s
          ..profileName = _str(m['profileName'], s.profileName)
          ..currencySymbol = _str(m['currencySymbol'], s.currencySymbol)
          ..currencyCode = _str(m['currencyCode'], s.currencyCode)
          ..darkMode = m['darkMode'] == true
          ..notificationsEnabled = m['notificationsEnabled'] != false
          ..locale = m['locale'] as String?
          ..onboardingCompleted = m['onboardingCompleted'] == true
          ..budgetWarningsEnabled = m['budgetWarningsEnabled'] != false
          ..billRemindersEnabled = m['billRemindersEnabled'] != false
          ..unusualSpendingEnabled = m['unusualSpendingEnabled'] != false
          ..weeklySummaryEnabled = m['weeklySummaryEnabled'] == true
          ..dailyBudget = (m['dailyBudget'] as num?)?.toDouble();
        return s;
      case HiveBoxes.users:
        return User(
          id: _str(m['id'], 'default_user'),
          name: _str(m['name']),
          currencySymbol: _str(m['currencySymbol'], 'UGX'),
          currencyCode: _str(m['currencyCode'], 'UGX'),
          locale: m['locale'] as String?,
          darkMode: m['darkMode'] == true,
          notificationsEnabled: m['notificationsEnabled'] != false,
          phone: _str(m['phone']),
          email: _str(m['email']),
          incomeSource: _str(m['incomeSource'], 'salary'),
          occupation: m['occupation'] as String?,
          createdAt: _date(m['createdAt']),
          dateOfBirth: _date(m['dateOfBirth']),
          incomeFrequency: _enum(IncomeFrequency.values, m['incomeFrequency'], IncomeFrequency.monthly),
          expectedMonthlyIncome: _dbl(m['expectedMonthlyIncome']),
          incomeType: _enum(IncomeType.values, m['incomeType'], IncomeType.formal),
          isVariable: m['isVariable'] == true,
          lastPayDate: _date(m['lastPayDate']),
        );
      case HiveBoxes.savingsGoals:
        return SavingsGoal(
          id: _str(m['id']),
          name: _str(m['name']),
          targetAmount: _dbl(m['targetAmount']),
          currentAmount: _dbl(m['currentAmount']),
          deadline: _date(m['deadline']) ?? DateTime.now(),
          icon: _str(m['icon'], 'savings'),
          color: _int(m['color'], 0xFF26A69A),
          imagePath: m['imagePath'] as String?,
          autoContributionRate: _dbl(m['autoContributionRate']),
          roundUpEnabled: m['roundUpEnabled'] == true,
          createdAt: _date(m['createdAt']),
          isPaused: m['isPaused'] == true,
        );
      case HiveBoxes.bills:
        return Bill(
          id: _str(m['id']),
          name: _str(m['name']),
          amount: _dbl(m['amount']),
          dueDate: _date(m['dueDate']) ?? DateTime.now(),
          walletId: _str(m['walletId']),
          categoryId: m['categoryId'] as String?,
          reminderDaysBefore: _int(m['reminderDaysBefore'], 3),
          recurrenceRuleId: m['recurrenceRuleId'] as String?,
          isPaid: m['isPaid'] == true,
          frequency: _enum(Frequency.values, m['frequency'], Frequency.monthly),
          customDays: (m['customDays'] as num?)?.toInt(),
          isPaused: m['isPaused'] == true,
          lastPaidDate: _date(m['lastPaidDate']),
        );
      case HiveBoxes.debts:
        return Debt(
          id: _str(m['id']),
          counterparty: _str(m['counterparty']),
          amount: _dbl(m['amount']),
          direction: _enum(DebtDirection.values, m['direction'], DebtDirection.owedByMe),
          dueDate: _date(m['dueDate']),
          description: m['description'] as String?,
          isSettled: m['isSettled'] == true,
          createdAt: _date(m['createdAt']),
        );
      case HiveBoxes.recurrenceRules:
        return RecurrenceRule(
          id: _str(m['id']),
          frequency: _enum(RecurrenceFrequency.values, m['frequency'], RecurrenceFrequency.monthly),
          interval: _int(m['interval'], 1),
          nextRunAt: _date(m['nextRunAt']),
          endDate: _date(m['endDate']),
          autoPost: m['autoPost'] == true,
        );
      case HiveBoxes.alertRules:
        return AlertRule(
          id: _str(m['id']),
          type: _enum(AlertType.values, m['type'], AlertType.budgetWarning),
          targetId: _str(m['targetId']),
          threshold: _dbl(m['threshold'], 80),
          isActive: m['isActive'] != false,
          message: m['message'] as String?,
          createdAt: _date(m['createdAt']),
        );
    }
    throw ArgumentError('Box "$box" is not synced');
  }

  static Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

  static DateTime? _date(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
  static double _dbl(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
