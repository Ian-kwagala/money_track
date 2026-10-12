import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/ui/auto_capture/auto_capture_screen.dart';
import 'package:money_track/ui/widgets/capture_review_banner.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';

import 'capture_test_helpers.dart';

Widget _app(Phone phone, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<TrackerViewModel>.value(value: phone.vm),
        ChangeNotifierProvider<CaptureService>.value(value: phone.capture),
      ],
      child: MaterialApp(home: home, routes: {'/capture': (_) => const AutoCaptureScreen()}),
    );

void main() {
  late Phone phone;

  setUp(() => Phone.now = DateTime(2026, 10, 12, 9, 0));
  tearDown(() async => phone.shutdown());

  testWidgets('before turning on, the screen offers to', (tester) async {
    await tester.runAsync(() async => phone = await Phone.boot());
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));

    expect(find.text('0 to review'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('a card shows what was read, and Confirm saves it and offers to fix the balance', (tester) async {
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(umeme)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));

    expect(find.text('1 to review'), findsOneWidget);
    expect(find.text('Paid · UGX 5,000'), findsOneWidget);
    expect(find.text('UMEME Limited'), findsOneWidget);
    expect(find.text('Airtel Money SMS · Airtel Money'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Confirm'));
      // Marking the message confirmed is the last thing confirming does.
      await until(() => phone.capture.pendingCount == 0);
    });
    await tester.pumpAndSettle();

    final saved = phone.vm.transactions.single;
    expect(saved.type, TxType.expense);
    expect(saved.amount, 5000);
    expect(saved.categoryId, 'cat_expense_electricity');
    expect(find.text('Update wallet balance?'), findsOneWidget);
    expect(find.textContaining('your SMS says UGX 2,675'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Update'));
      // Stored balances are refreshed last.
      await until(() => phone.vm.walletById('wallet_airtel').currentBalance == 2675);
    });
    await tester.pumpAndSettle();

    expect(phone.vm.walletBalance('wallet_airtel'), 2675);
    expect(find.text('0 to review'), findsOneWidget);
    expect(find.text('Recently handled'), findsOneWidget);
  });

  testWidgets('Confirm on a card with no category opens the review sheet instead', (tester) async {
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(airtelSent)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));
    expect(find.text('Choose category'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Original message'), findsOneWidget);
    expect(phone.vm.transactions, isEmpty);
  });

  testWidgets('Home banner counts what is waiting and opens the list', (tester) async {
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(umeme), sms(airtelSent)]);
    });
    await tester.pumpWidget(_app(phone, const Scaffold(body: CaptureReviewBanner())));

    expect(find.text('2 transactions to review'), findsOneWidget);
    await tester.tap(find.text('2 transactions to review'));
    await tester.pumpAndSettle();
    expect(find.text('2 to review'), findsOneWidget);
  });
}
