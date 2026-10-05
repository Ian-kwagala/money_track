import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/data/hive_boxes.dart';
import 'package:money_track/models/alert_rule.dart';
import 'package:money_track/models/app_settings.dart';
import 'package:money_track/models/bill.dart';
import 'package:money_track/models/budget.dart';
import 'package:money_track/models/category.dart';
import 'package:money_track/models/debt.dart';
import 'package:money_track/models/frequency.dart';
import 'package:money_track/models/income_profile.dart';
import 'package:money_track/models/recurrence_rule.dart';
import 'package:money_track/models/savings_goal.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/models/user.dart';
import 'package:money_track/models/wallet.dart';
import 'package:money_track/services/cloud/cloud_codec.dart';

/// One sample per synced box, with every field set to a NON-default value,
/// so a field that encode or decode forgets shows up as a mismatch.
final _t1 = DateTime(2026, 3, 4, 5, 6, 7);
final _t2 = DateTime(2025, 12, 31, 23, 59);

Map<String, Object> _samples() => {
      HiveBoxes.wallets: Wallet(
        id: 'w1', name: 'MTN', type: WalletType.mobileMoney, icon: 'phone',
        color: 0xFF112233, openingBalance: 1500, currentBalance: 2500.5,
      ),
      HiveBoxes.categories: Category(
        id: 'c1', name: 'Boda', icon: 'directions_bus', color: 0xFF445566,
        type: TxType.income, parentCategoryId: 'c0', isBuiltIn: true, frequency: 'once',
      ),
      HiveBoxes.transactions: TxRecord(
        id: 't1', type: TxType.transfer, amount: 12500, walletId: 'w1', toWalletId: 'w2',
        categoryId: 'c1', note: 'rent', dateTime: _t1, receiptPath: '/r.jpg',
        isRecurring: true, frequency: Frequency.quarterly,
      ),
      HiveBoxes.budgets: Budget(
        id: 'b1', categoryId: 'c1', amount: 300000, periodStart: _t1,
        repeatsMonthly: false, rollover: true, frequency: Frequency.weekly,
      ),
      HiveBoxes.users: User(
        id: 'u1', name: 'Nakato', currencySymbol: 'USh', currencyCode: 'USD', locale: 'en_UG',
        darkMode: true, notificationsEnabled: false, phone: '0700', email: 'n@x.ug',
        incomeSource: 'informal', occupation: 'trader', createdAt: _t1, dateOfBirth: _t2,
        incomeFrequency: IncomeFrequency.weekly, expectedMonthlyIncome: 900000,
        incomeType: IncomeType.variable, isVariable: true, lastPayDate: _t2,
      ),
      HiveBoxes.savingsGoals: SavingsGoal(
        id: 'g1', name: 'Laptop', targetAmount: 6400000, currentAmount: 2100000, deadline: _t1,
        icon: 'laptop', color: 0xFF778899, imagePath: '/g.jpg', autoContributionRate: 0.1,
        roundUpEnabled: true, createdAt: _t2, isPaused: true,
      ),
      HiveBoxes.bills: Bill(
        id: 'bl1', name: 'Water', amount: 54000, dueDate: _t1, walletId: 'w1', categoryId: 'c1',
        reminderDaysBefore: 7, recurrenceRuleId: 'r1', isPaid: true, frequency: Frequency.custom,
        customDays: 45, isPaused: true, lastPaidDate: _t2,
      ),
      HiveBoxes.debts: Debt(
        id: 'd1', counterparty: 'Mama', amount: 50000, direction: DebtDirection.owedToMe,
        dueDate: _t1, description: 'school', isSettled: true, createdAt: _t2,
      ),
      HiveBoxes.recurrenceRules: RecurrenceRule(
        id: 'r1', frequency: RecurrenceFrequency.yearly, interval: 3, nextRunAt: _t1,
        endDate: _t2, autoPost: true,
      ),
      HiveBoxes.alertRules: AlertRule(
        id: 'a1', type: AlertType.goalPace, targetId: 'g1', threshold: 95, isActive: false,
        message: 'hurry', createdAt: _t2,
      ),
      HiveBoxes.settings: AppSettings(
        profileName: 'Nakato', currencySymbol: 'USh', currencyCode: 'USD', darkMode: true,
        notificationsEnabled: false, locale: 'en_UG', onboardingCompleted: true,
        budgetWarningsEnabled: false, billRemindersEnabled: false, unusualSpendingEnabled: false,
        weeklySummaryEnabled: true, dailyBudget: 20000,
      ),
    };

void main() {
  test('every synced box has a sample', () {
    expect(_samples().keys.toSet(), CloudCodec.syncedBoxes.toSet());
  });

  for (final entry in _samples().entries) {
    test('${entry.key} survives encode → decode → encode unchanged', () {
      final encoded = CloudCodec.encode(entry.key, entry.value);
      final decoded = CloudCodec.decode(entry.key, Map<String, dynamic>.of(encoded));
      expect(CloudCodec.encode(entry.key, decoded), encoded);
    });
  }

  group('app lock never leaves the device', () {
    final settings = AppSettings(
      appLockEnabled: true,
      appLockPin: '1234',
      appLockPasswordHash: 'hash',
    );

    test('PIN, password hash and lock flag are not encoded', () {
      final encoded = CloudCodec.encode(HiveBoxes.settings, settings);
      expect(encoded.keys, isNot(contains('appLockPin')));
      expect(encoded.keys, isNot(contains('appLockPasswordHash')));
      expect(encoded.keys, isNot(contains('appLockEnabled')));
      expect(encoded.values, isNot(contains('1234')));
    });

    test('applying cloud settings keeps the local lock', () {
      final local = AppSettings(appLockEnabled: true, appLockPin: '1234', appLockPasswordHash: 'hash');
      final cloud = CloudCodec.encode(HiveBoxes.settings, AppSettings(profileName: 'Other', darkMode: true));
      final merged = CloudCodec.decode(HiveBoxes.settings, cloud, existing: local) as AppSettings;
      expect(merged.profileName, 'Other');
      expect(merged.darkMode, isTrue);
      expect(merged.appLockEnabled, isTrue);
      expect(merged.appLockPin, '1234');
      expect(merged.appLockPasswordHash, 'hash');
    });
  });

  test('unknown enum names fall back instead of crashing', () {
    final decoded = CloudCodec.decode(HiveBoxes.wallets, {'id': 'w', 'name': 'x', 'type': 'crypto'}) as Wallet;
    expect(decoded.type, WalletType.cash);
  });
}
