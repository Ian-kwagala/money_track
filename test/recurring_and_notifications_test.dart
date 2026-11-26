import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:money_track/data/money_repository.dart';
import 'package:money_track/models/bill.dart';
import 'package:money_track/models/frequency.dart';
import 'package:money_track/models/recurrence_rule.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/services/alerts_service.dart';
import 'package:money_track/services/budget_notification_service.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/services/cloud/announcement_service.dart';
import 'package:money_track/services/recurring_transaction_service.dart';
import 'package:money_track/ui/dashboard/dashboard_screen.dart';
import 'package:money_track/ui/theme/app_theme.dart';
import 'package:money_track/ui/widgets/receipt_picker.dart';
import 'package:money_track/ui/widgets/transaction_tile.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'capture/capture_test_helpers.dart' show FakeSmsBridge;

class _FakeNotificationBridge implements NotificationBridge {
  final List<({int id, String title, String body})> sent = [];
  bool permissionRequested = false;

  @override
  Future<void> requestPermission() async {
    permissionRequested = true;
  }

  @override
  Future<void> show({required int id, required String title, required String body}) async {
    sent.add((id: id, title: title, body: body));
  }
}

Future<({Directory dir, TrackerViewModel vm})> _bootVm() async {
  final dir = await Directory.systemTemp.createTemp('mt_rec_notif_test');
  final repo = MoneyRepository();
  await repo.init(hivePath: dir.path);
  return (dir: dir, vm: TrackerViewModel(repo));
}

Future<void> _closeVm(Directory dir) async {
  await Hive.close();
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecurringTransactionService', () {
    test('auto-posts due recurring expenses once and advances nextDueDate', () async {
      final env = await _bootVm();
      try {
        final vm = env.vm;
        final walletId = vm.wallets.first.id;
        final catId = vm.expenseCategories.first.id;

        final rule = RecurrenceRule(
          id: 'rule_netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          nextRunAt: DateTime(2026, 11, 1),
          autoPost: true,
        );
        final bill = Bill(
          id: 'bill_netflix',
          name: 'Netflix',
          amount: 45000,
          dueDate: DateTime(2026, 11, 1),
          walletId: walletId,
          categoryId: catId,
          recurrenceRuleId: rule.id,
          frequency: Frequency.monthly,
        );

        await vm.addRecurrenceRule(rule);
        await vm.addBill(bill);

        final firstCount = await RecurringTransactionService.processDueRecurring(
          vm,
          now: DateTime(2026, 11, 15),
        );
        expect(firstCount, 1);
        expect(vm.transactions, hasLength(1));
        expect(vm.transactions.first.note, 'Netflix');
        expect(vm.transactions.first.amount, 45000);
        expect(vm.transactions.first.isRecurring, isTrue);

        // Next due date should have advanced to December 1.
        final updatedBill = vm.bills.firstWhere((b) => b.id == 'bill_netflix');
        expect(updatedBill.nextDueDate, DateTime(2026, 12, 1));

        // Running again on the same day must not create a duplicate.
        final secondCount = await RecurringTransactionService.processDueRecurring(
          vm,
          now: DateTime(2026, 11, 15),
        );
        expect(secondCount, 0);
        expect(vm.transactions, hasLength(1));
      } finally {
        await _closeVm(env.dir);
      }
    });

    test('skips paused bills and bills without autoPost', () async {
      final env = await _bootVm();
      try {
        final vm = env.vm;
        final walletId = vm.wallets.first.id;

        final pausedRule = RecurrenceRule(
          id: 'rule_paused',
          frequency: RecurrenceFrequency.monthly,
          autoPost: true,
        );
        final pausedBill = Bill(
          id: 'bill_paused',
          name: 'Gym',
          amount: 80000,
          dueDate: DateTime(2026, 11, 1),
          walletId: walletId,
          recurrenceRuleId: pausedRule.id,
          isPaused: true,
        );
        final manualBill = Bill(
          id: 'bill_manual',
          name: 'Water',
          amount: 30000,
          dueDate: DateTime(2026, 11, 1),
          walletId: walletId,
        );

        await vm.addRecurrenceRule(pausedRule);
        await vm.addBill(pausedBill);
        await vm.addBill(manualBill);

        final count = await RecurringTransactionService.processDueRecurring(
          vm,
          now: DateTime(2026, 11, 20),
        );
        expect(count, 0);
        expect(vm.transactions, isEmpty);
      } finally {
        await _closeVm(env.dir);
      }
    });
  });

  group('BudgetNotificationService & monthly limit alerts', () {
    test('fires 80% warning once and 100% exceeded alert once per month', () async {
      final env = await _bootVm();
      try {
        final vm = env.vm;
        final walletId = vm.wallets.first.id;
        final catId = vm.expenseCategories.first.id;
        final now = DateTime(2026, 11, 20, 10, 0);
        final bridge = _FakeNotificationBridge();
        final service = BudgetNotificationService(
          vm: vm,
          bridge: bridge,
          clock: () => now,
        );

        await vm.setMonthlySpendingLimit(100000);
        await service.start();
        expect(bridge.permissionRequested, isTrue);
        expect(bridge.sent, isEmpty);

        // 50% spent -> no notification.
        await vm.addTransaction(TxRecord(
          id: 'tx_50',
          type: TxType.expense,
          amount: 50000,
          walletId: walletId,
          categoryId: catId,
          dateTime: now,
        ));
        await service.checkNow();
        expect(bridge.sent, isEmpty);

        // 85% spent -> 80% notification fires once.
        await vm.addTransaction(TxRecord(
          id: 'tx_85',
          type: TxType.expense,
          amount: 35000,
          walletId: walletId,
          categoryId: catId,
          dateTime: now,
        ));
        await service.checkNow();
        await service.checkNow(); // duplicate check should not re-send
        expect(bridge.sent, hasLength(1));
        expect(bridge.sent.first.id, BudgetNotificationService.idWarning80);
        expect(bridge.sent.first.title, contains('80%'));

        // In-app AlertsService also reports the 80% alert.
        final alerts80 = AlertsService.build(vm, 'UGX', now);
        expect(alerts80.any((a) => a.id == 'monthly_limit_80_2026_11'), isTrue);

        // 110% spent -> 100% exceeded notification fires once.
        await vm.addTransaction(TxRecord(
          id: 'tx_110',
          type: TxType.expense,
          amount: 25000,
          walletId: walletId,
          categoryId: catId,
          dateTime: now,
        ));
        await service.checkNow();
        await service.checkNow();
        expect(bridge.sent, hasLength(2));
        expect(bridge.sent.last.id, BudgetNotificationService.idExceeded100);
        expect(bridge.sent.last.title, contains('exceeded'));

        final alerts100 = AlertsService.build(vm, 'UGX', now);
        expect(alerts100.any((a) => a.id == 'monthly_limit_over_2026_11'), isTrue);

        service.dispose();
      } finally {
        await _closeVm(env.dir);
      }
    });
  });

  group('Dark theme & receipt indicator UI', () {
    testWidgets('DashboardScreen renders cleanly with AppTheme.dark and dark palette',
        (tester) async {
      late Directory dir;
      late TrackerViewModel vm;
      late CaptureService capture;

      await tester.runAsync(() async {
        final env = await _bootVm();
        dir = env.dir;
        vm = env.vm;
        await vm.updateSettings(vm.settings..darkMode = true);
        capture = CaptureService(vm: vm, bridge: FakeSmsBridge());
        await capture.start(watchLifecycle: false);
      });
      addTearDown(() async {
        capture.dispose();
        await tester.runAsync(() => _closeVm(dir));
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TrackerViewModel>.value(value: vm),
            ChangeNotifierProvider<CaptureService>.value(value: capture),
            ChangeNotifierProvider(create: (_) => AnnouncementService()),
            ChangeNotifierProvider(create: (_) => AlertsService()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.darkBg);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });

    testWidgets('TransactionTile shows receipt badge and opens ReceiptViewer on tap',
        (tester) async {
      late Directory dir;
      late TrackerViewModel vm;

      await tester.runAsync(() async {
        final env = await _bootVm();
        dir = env.dir;
        vm = env.vm;
      });
      addTearDown(() => tester.runAsync(() => _closeVm(dir)));

      final tx = TxRecord(
        id: 'tx_receipt_1',
        type: TxType.expense,
        amount: 15000,
        walletId: vm.wallets.first.id,
        categoryId: vm.expenseCategories.first.id,
        note: 'Supermarket',
        dateTime: DateTime.now(),
        receiptPath: '/tmp/fake_receipt.jpg',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<TrackerViewModel>.value(
          value: vm,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(body: TransactionTile(tx: tx)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badge = find.byKey(const Key('receipt_badge_tx_receipt_1'));
      expect(badge, findsOneWidget);

      await tester.tap(badge);
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptViewer), findsOneWidget);
    });
  });
}
