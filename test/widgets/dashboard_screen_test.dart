import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:money_track/data/hive_boxes.dart';
import 'package:money_track/data/money_repository.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/services/alerts_service.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/services/cloud/announcement_service.dart';
import 'package:money_track/services/cloud/auth_service.dart';
import 'package:money_track/services/cloud/connectivity_service.dart';
import 'package:money_track/services/cloud/sync_service.dart';
import 'package:money_track/ui/add_transaction/add_transaction_screen.dart';
import 'package:money_track/ui/dashboard/category_expense_pie_chart.dart';
import 'package:money_track/ui/dashboard/dashboard_screen.dart';
import 'package:money_track/ui/dashboard/monthly_budget_card.dart';
import 'package:money_track/ui/widgets/transaction_tile.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/capture_test_helpers.dart' show FakeSmsBridge, until;
import 'real_fonts.dart';
import 'test_theme.dart';

class _FakeAuth extends AuthService {
  final _changes = StreamController<fb.User?>.broadcast();
  String? _uid = 'u_test';

  @override
  bool get isAvailable => true;

  @override
  bool get isSignedIn => _uid != null;

  @override
  String? get uid => _uid;

  @override
  String? get email => _uid == null ? null : '$_uid@example.com';

  @override
  String? get displayName => 'Test User';

  @override
  DateTime? get accountCreatedAt => DateTime(2026, 1, 1);

  @override
  Stream<fb.User?> get userChanges => _changes.stream;

  @override
  Future<void> signOut() async {
    _uid = null;
    _changes.add(null);
  }
}

class _TestEnv {
  _TestEnv({
    required this.dir,
    required this.vm,
    required this.capture,
    required this.sync,
    required this.auth,
    required this.connectivity,
    required this.cloud,
  });

  final Directory dir;
  final TrackerViewModel vm;
  final CaptureService capture;
  final SyncService sync;
  final _FakeAuth auth;
  final ConnectivityService connectivity;
  final FakeFirebaseFirestore cloud;

  static Future<_TestEnv> boot({bool syncEnabled = false}) async {
    final dir = await Directory.systemTemp.createTemp('mt_dash_test');
    final repo = MoneyRepository();
    await repo.init(hivePath: dir.path);
    final cloud = FakeFirebaseFirestore();
    final auth = _FakeAuth();
    final connectivity = ConnectivityService.manual(online: true);
    final sync = SyncService(
      repo: repo,
      auth: auth,
      connectivity: connectivity,
      firestore: cloud,
      enabled: syncEnabled,
    );
    final vm = TrackerViewModel(repo);
    final capture = CaptureService(vm: vm, bridge: FakeSmsBridge());
    await sync.start();
    await capture.start(watchLifecycle: false);
    return _TestEnv(
      dir: dir,
      vm: vm,
      capture: capture,
      sync: sync,
      auth: auth,
      connectivity: connectivity,
      cloud: cloud,
    );
  }

  Future<void> shutdown() async {
    sync.dispose();
    capture.dispose();
    await Hive.close();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}

void main() {
  _TestEnv? env;

  setUpAll(loadRealFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> bootForWidgetTest(WidgetTester tester, {bool syncEnabled = false}) async {
    await tester.runAsync(() async {
      env = await _TestEnv.boot(syncEnabled: syncEnabled);
    });
    addTearDown(() async {
      final activeEnv = env;
      env = null;
      if (activeEnv != null) {
        await tester.runAsync(() => activeEnv.shutdown());
      }
    });
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(420, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TrackerViewModel>.value(value: env!.vm),
          ChangeNotifierProvider<CaptureService>.value(value: env!.capture),
          ChangeNotifierProvider<AuthService>.value(value: env!.auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: env!.connectivity),
          ChangeNotifierProvider<SyncService>.value(value: env!.sync),
          ChangeNotifierProvider(create: (_) => AnnouncementService()),
          ChangeNotifierProvider(create: (_) => AlertsService()),
        ],
        child: MaterialApp(
          theme: testAppTheme(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder verticalScrollable() => find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  test('CategoryExpensePieChart.groupOverflow keeps top 6 and groups rest into Other', () {
    final raw = [
      for (var i = 1; i <= 8; i++)
        CategoryExpenseSlice(
          name: 'Cat $i',
          amount: i * 1000.0,
          color: Colors.teal,
        ),
    ];

    final grouped = CategoryExpensePieChart.groupOverflow(raw, maxSlices: 6);
    expect(grouped, hasLength(7));
    expect(grouped.first.name, 'Cat 8');
    expect(grouped.last.name, 'Other');
    expect(grouped.last.amount, 3000.0); // Cat 1 (1000) + Cat 2 (2000)
  });

  testWidgets('displays category pie chart, total expenses summary, and Firestore sync pill',
      (tester) async {
    await bootForWidgetTest(tester, syncEnabled: true);
    await tester.runAsync(() async {
      final now = DateTime.now();
      final walletId = env!.vm.wallets.first.id;
      final cats = env!.vm.expenseCategories;
      await env!.vm.addTransaction(TxRecord(
        id: 'tx_food',
        type: TxType.expense,
        amount: 60000,
        walletId: walletId,
        categoryId: cats[0].id,
        note: 'Java House lunch',
        dateTime: now,
      ));
      await env!.vm.addTransaction(TxRecord(
        id: 'tx_transport',
        type: TxType.expense,
        amount: 40000,
        walletId: walletId,
        categoryId: cats[1].id,
        note: 'Boda ride',
        dateTime: now,
      ));
      await env!.sync.flushNow();
    });

    await pumpDashboard(tester);

    expect(find.text('Total expenses'), findsOneWidget);
    expect(find.text('UGX 100,000'), findsWidgets);
    expect(find.text('Expenses by category'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.textContaining('Cloud sync'), findsOneWidget);
  });

  testWidgets('allows setting monthly spending limit and shows remaining budget',
      (tester) async {
    await bootForWidgetTest(tester);
    await tester.runAsync(() async {
      final walletId = env!.vm.wallets.first.id;
      final catId = env!.vm.expenseCategories.first.id;
      await env!.vm.addTransaction(TxRecord(
        id: 'tx_1',
        type: TxType.expense,
        amount: 150000,
        walletId: walletId,
        categoryId: catId,
        note: 'Groceries',
        dateTime: DateTime.now(),
      ));
    });

    await pumpDashboard(tester);

    final cardFinder = find.byType(MonthlyBudgetCard);
    await tester.scrollUntilVisible(cardFinder, 200, scrollable: verticalScrollable());
    await tester.pumpAndSettle();

    expect(find.text('Set limit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('set_monthly_limit_button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('monthly_limit_input')), '500000');
    await tester.pump();
    var notified = false;
    void listener() => notified = true;
    env!.vm.addListener(listener);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save_monthly_limit_button')));
      await until(() => notified);
    });
    env!.vm.removeListener(listener);
    await tester.pumpAndSettle();

    expect(env!.vm.effectiveMonthlyLimit, 500000);
    expect(find.text('UGX 350,000 remaining'), findsOneWidget);
    expect(find.text('30% used'), findsOneWidget);
  });

  testWidgets('search bar filters recent transactions by note, category, and title',
      (tester) async {
    await bootForWidgetTest(tester);
    await tester.runAsync(() async {
      final wallets = env!.vm.wallets;
      final food = env!.vm.expenseCategories.firstWhere((c) => c.name == 'Food');
      final transport = env!.vm.expenseCategories.firstWhere((c) => c.name == 'Transport');
      final now = DateTime.now();

      await env!.vm.addTransaction(TxRecord(
        id: 't_note',
        type: TxType.expense,
        amount: 12000,
        walletId: wallets.first.id,
        categoryId: food.id,
        note: 'Java House coffee',
        dateTime: now,
      ));
      await env!.vm.addTransaction(TxRecord(
        id: 't_cat',
        type: TxType.expense,
        amount: 8000,
        walletId: wallets.first.id,
        categoryId: transport.id,
        note: '',
        dateTime: now.subtract(const Duration(minutes: 5)),
      ));
      if (wallets.length >= 2) {
        await env!.vm.addTransaction(TxRecord(
          id: 't_transfer',
          type: TxType.transfer,
          amount: 25000,
          walletId: wallets[0].id,
          toWalletId: wallets[1].id,
          note: '',
          dateTime: now.subtract(const Duration(minutes: 10)),
        ));
      }
      await env!.sync.flushNow();
    });

    await pumpDashboard(tester);

    final searchBar = find.byKey(const Key('dashboard_search_bar'));
    await tester.scrollUntilVisible(searchBar, 200, scrollable: verticalScrollable());
    await tester.pumpAndSettle();

    Finder inRecentTiles(String text) => find.descendant(
          of: find.byType(TransactionTile),
          matching: find.text(text),
        );

    // Filter by note
    await tester.enterText(searchBar, 'Java House');
    await tester.pumpAndSettle();
    expect(inRecentTiles('Java House coffee'), findsOneWidget);
    expect(inRecentTiles('Transport'), findsNothing);

    // Filter by category
    await tester.enterText(searchBar, 'Transport');
    await tester.pumpAndSettle();
    expect(inRecentTiles('Transport'), findsOneWidget);
    expect(inRecentTiles('Java House coffee'), findsNothing);

    // Filter by transfer display title (wallet name)
    if (env!.vm.wallets.length >= 2) {
      final firstWalletName = env!.vm.wallets[0].name;
      await tester.enterText(searchBar, firstWalletName);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(TransactionTile), matching: find.textContaining('→')),
        findsOneWidget,
      );
      expect(inRecentTiles('Java House coffee'), findsNothing);
    }

    // Clear search
    await tester.tap(find.byKey(const Key('dashboard_search_clear')));
    await tester.pumpAndSettle();
    expect(inRecentTiles('Java House coffee'), findsOneWidget);
    expect(inRecentTiles('Transport'), findsOneWidget);
  });

  testWidgets('shows over-limit warning when monthly expenses exceed spending limit',
      (tester) async {
    await bootForWidgetTest(tester);
    await tester.runAsync(() async {
      await env!.vm.setMonthlySpendingLimit(100000);
      await env!.vm.addTransaction(TxRecord(
        id: 'tx_over',
        type: TxType.expense,
        amount: 125000,
        walletId: env!.vm.wallets.first.id,
        categoryId: env!.vm.expenseCategories.first.id,
        note: 'Rent',
        dateTime: DateTime.now(),
      ));
      await env!.sync.flushNow();
    });

    await pumpDashboard(tester);

    final cardFinder = find.byType(MonthlyBudgetCard);
    await tester.scrollUntilVisible(cardFinder, 200, scrollable: verticalScrollable());
    await tester.pumpAndSettle();

    expect(find.text('UGX 25,000 over limit'), findsOneWidget);
    expect(find.text('125% used'), findsOneWidget);
  });

  testWidgets('opening transaction form from dashboard saves entry',
      (tester) async {
    await bootForWidgetTest(tester);

    await pumpDashboard(tester);

    final addBtn = find.byKey(const Key('dashboard_add_transaction_button'));
    await tester.scrollUntilVisible(addBtn, 200, scrollable: verticalScrollable());
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AddTransactionScreen), findsOneWidget);

    // Enter amount and note on the transaction form.
    await tester.enterText(find.byType(TextField).first, '45000');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Java House'), 'Market shopping');
    await tester.pump();

    final saveBtn = find.text('Save');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(saveBtn);
      await until(() => env!.vm.transactions.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();

    expect(env!.vm.transactions, hasLength(1));
    final saved = env!.vm.transactions.first;
    expect(saved.amount, 45000);
    expect(saved.note, 'Market shopping');
  });

  test('new transactions and monthly spending limit sync to Firestore', () async {
    final localEnv = await _TestEnv.boot(syncEnabled: true);
    try {
      final walletId = localEnv.vm.wallets.first.id;
      final catId = localEnv.vm.expenseCategories.first.id;

      await localEnv.vm.setMonthlySpendingLimit(500000);
      await localEnv.vm.addTransaction(TxRecord(
        id: 'tx_firestore',
        type: TxType.expense,
        amount: 45000,
        walletId: walletId,
        categoryId: catId,
        note: 'Market shopping',
        dateTime: DateTime(2026, 11, 20, 14, 30),
      ));
      await localEnv.sync.flushNow();

      final settingsSnap = await localEnv.cloud
          .collection('users')
          .doc('u_test')
          .collection(HiveBoxes.settings)
          .doc('default')
          .get();
      expect(settingsSnap.exists, isTrue);
      expect((settingsSnap.data()!['data'] as Map)['monthlySpendingLimit'], 500000);

      final txSnap = await localEnv.cloud
          .collection('users')
          .doc('u_test')
          .collection(HiveBoxes.transactions)
          .doc('tx_firestore')
          .get();
      expect(txSnap.exists, isTrue);
      expect((txSnap.data()!['data'] as Map)['amount'], 45000);
      expect((txSnap.data()!['data'] as Map)['note'], 'Market shopping');
    } finally {
      await localEnv.shutdown();
    }
  });
}
