import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/ui/reports/balance_trend_card.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';

import '../capture/capture_test_helpers.dart';
import 'real_fonts.dart';
import 'test_theme.dart';

final _now = DateTime(2026, 10, 13, 15, 0);

void main() {
  late Phone phone;

  setUpAll(loadRealFonts);
  tearDown(() async => phone.shutdown());

  Future<void> pumpCard(WidgetTester tester, {bool withMoney = true}) async {
    tester.view
      ..physicalSize = const Size(390, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      if (!withMoney) return;
      // A salary every month and some spending every few days: the balance grows.
      for (var m = 0; m < 12; m++) {
        await phone.vm.addTransaction(TxRecord(
          id: 'pay$m',
          type: TxType.income,
          amount: 1500000,
          walletId: 'wallet_bank',
          categoryId: 'cat_income_salary',
          dateTime: DateTime(_now.year, _now.month - m, 1, 9),
        ));
      }
      for (var d = 0; d < 360; d += 3) {
        await phone.vm.addTransaction(TxRecord(
          id: 'spend$d',
          type: TxType.expense,
          amount: 25000,
          walletId: 'wallet_mtn',
          categoryId: 'cat_expense_food',
          dateTime: _now.subtract(Duration(days: d, hours: 2)),
        ));
      }
    });
    await tester.pumpWidget(ChangeNotifierProvider<TrackerViewModel>.value(
      value: phone.vm,
      child: MaterialApp(
        theme: testAppTheme(),
        home: Scaffold(body: SingleChildScrollView(child: BalanceTrendCard(clock: () => _now))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  LineChartData chart(WidgetTester tester) => tester.widget<LineChart>(find.byType(LineChart)).data;
  List<double> totals(WidgetTester tester) => [for (final s in chart(tester).lineBarsData.single.spots) s.y];

  testWidgets('shows the last 30 days by default; Week and Year switch the range', (tester) async {
    await pumpCard(tester);
    expect(totals(tester), hasLength(30));
    expect(find.textContaining('last 30 days'), findsWidgets);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(totals(tester), hasLength(7));

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(totals(tester), hasLength(12));
    expect(find.textContaining('last 12 months'), findsWidgets);
  });

  testWidgets('the line ends at the wallets\' total and the axis fits the numbers', (tester) async {
    await pumpCard(tester);
    final walletTotal = phone.vm.wallets.fold<double>(0, (s, w) => s + w.currentBalance);
    for (final range in ['Week', 'Month', 'Year']) {
      await tester.tap(find.text(range));
      await tester.pumpAndSettle();
      final data = chart(tester);
      final ys = totals(tester);
      expect(ys.last, walletTotal, reason: range);
      expect(data.minY, lessThanOrEqualTo(ys.reduce((a, b) => a < b ? a : b)), reason: range);
      expect(data.maxY, greaterThanOrEqualTo(ys.reduce((a, b) => a > b ? a : b)), reason: range);
      // Zoomed to the data: the line spans a good part of the chart's height.
      final used = (ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b)) / (data.maxY - data.minY);
      expect(used, greaterThan(0.4), reason: range);
    }
  });

  testWidgets('a year of saving shows as the balance going up', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    final ys = totals(tester);
    expect(ys.last, greaterThan(ys.first));
    expect(find.textContaining('↑'), findsOneWidget);
  });

  testWidgets('with no transactions it says so instead of a percentage', (tester) async {
    await pumpCard(tester, withMoney: false);
    expect(find.text('No transactions yet'), findsOneWidget);
  });
}
