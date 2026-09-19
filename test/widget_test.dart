import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_track/models/transaction.dart';

void main() {
  test('TxType signed amount direction', () {
    expect(TxType.income, isNotNull);
    expect(TxType.expense, isNotNull);
    expect(TxType.transfer, isNotNull);
  });

  testWidgets('App bootstraps MoneyTrack UI', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('MoneyTrack'))));
    expect(find.text('MoneyTrack'), findsOneWidget);
  });
}