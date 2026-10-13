import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/ui/auto_capture/auto_capture_screen.dart';
import 'package:money_track/ui/auto_capture/capture_review_sheet.dart';
import 'package:money_track/ui/widgets/action_button.dart';
import 'package:money_track/ui/widgets/capture_review_banner.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';

import '../widgets/real_fonts.dart';
import '../widgets/test_theme.dart';
import 'capture_test_helpers.dart';

Widget _app(Phone phone, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<TrackerViewModel>.value(value: phone.vm),
        ChangeNotifierProvider<CaptureService>.value(value: phone.capture),
      ],
      child: MaterialApp(theme: testAppTheme(), home: home, routes: {'/capture': (_) => const AutoCaptureScreen()}),
    );

void main() {
  late Phone phone;

  setUpAll(loadRealFonts);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Saved'), findsWidgets, reason: 'the button and the card show it was saved');
    // The balance question waits for the check and the card's exit.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
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
    await tester.pump(const Duration(seconds: 1)); // let the card fold away
    await tester.pumpAndSettle();
    expect(find.text('0 to review'), findsOneWidget);
    expect(find.text('Recently handled'), findsOneWidget);
    expect(find.text('UMEME Limited'), findsNothing, reason: 'the card has gone');
    expect(find.descendant(of: find.byType(ListTile), matching: find.textContaining('UMEME Limited')), findsOneWidget,
        reason: 'listed under Recently handled');
  });

  testWidgets('Confirm with no category asks for one, and picking it saves straight away', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(airtelSent)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));
    expect(find.text('Choose category'), findsOneWidget);

    // Tapped in real time: the save that follows the picker writes to storage.
    await tester.runAsync(() => tester.tap(find.text('Confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Pick a category to confirm'), findsOneWidget);
    expect(find.textContaining('Grace Akello gets this category automatically'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Rent'));
      await until(() => phone.capture.pendingCount == 0);
    });
    await tester.pump();
    final main = phone.vm.transactions.firstWhere((t) => !t.id.endsWith('_fee'));
    expect(main.categoryId, 'cat_expense_rent');
    expect(main.amount, 21000);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('0 to review'), findsOneWidget);
  });

  testWidgets('the category picker can hand over to the full editor', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(airtelSent)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit other details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('Pick a category to confirm'), findsOneWidget, reason: 'the editor says what is missing');
    expect(phone.vm.transactions, isEmpty);
  });

  testWidgets('Confirm on what looks like a duplicate asks first', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.vm.addTransaction(TxRecord(
        id: 'manual1',
        type: TxType.income,
        amount: 51000,
        walletId: 'wallet_airtel',
        categoryId: 'cat_income_other',
        dateTime: DateTime(2026, 10, 5, 19),
      ));
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(airtelReceived)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));

    await tester.runAsync(() => tester.tap(find.text('Confirm')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Already recorded?')), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Ignore SMS'));
      await until(() => phone.capture.pendingCount == 0);
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(phone.vm.transactions.single.id, 'manual1', reason: 'not counted twice');
    expect(find.text('0 to review'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the "Ignored" snackbar times out
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

  testWidgets('every card has its own Confirm, Edit and Ignore; confirming one leaves the rest', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(umeme), sms(airtelDeposit)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));

    expect(find.text('Confirm'), findsNWidgets(2));
    expect(find.text('Edit'), findsNWidgets(2));
    expect(find.text('Ignore'), findsNWidgets(2));

    await tester.runAsync(() async {
      await tester.tap(find.text('Confirm').first);
      await until(() => phone.capture.pendingCount == 1);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    }

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('1 to review'), findsOneWidget);
    expect(phone.vm.transactions, hasLength(1));
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('Edit corrects amount, fee, date, category and note before confirming', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(airtelSent)]); // 21,000 to Grace Akello, fee 500, 5 Oct 08:00
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final sheet = find.byType(CaptureReviewSheet);
    expect(find.text('Edit transaction'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount (UGX)'), '20,500');
    await tester.enterText(find.widgetWithText(TextField, 'Fee'), '300');
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Rent share');
    await tester.pump();
    expect(find.text('Sent · UGX 20,500'), findsOneWidget, reason: 'the heading follows the edited amount');

    final date = find.byIcon(Icons.calendar_today_outlined);
    await tester.ensureVisible(date);
    await tester.pumpAndSettle();
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final rent = find.descendant(of: sheet, matching: find.widgetWithText(ChoiceChip, 'Rent'));
    await tester.ensureVisible(rent);
    await tester.tap(rent);
    await tester.pump();

    final confirm = find.descendant(of: sheet, matching: find.text('Confirm'));
    await tester.ensureVisible(confirm);
    await tester.runAsync(() async {
      await tester.tap(confirm);
      await until(() => phone.capture.pendingCount == 0);
      await Future<void>.delayed(const Duration(milliseconds: 800)); // check mark, then the sheet closes
    });
    await tester.pumpAndSettle();
    expect(find.byType(CaptureReviewSheet), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final main = phone.vm.transactions.firstWhere((t) => !t.id.endsWith('_fee'));
    final fee = phone.vm.transactions.firstWhere((t) => t.id.endsWith('_fee'));
    expect(main.amount, 20500);
    expect(main.note, 'Rent share');
    expect(main.categoryId, 'cat_expense_rent');
    expect(main.dateTime, DateTime(2026, 10, 4, 8, 0));
    expect(fee.amount, 300);
  });

  testWidgets('Confirm in the Edit sheet stays off until the amount is valid', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await phone.capture.turnOn();
      await phone.capture.ingest([sms(umeme)]);
    });
    await tester.pumpWidget(_app(phone, const AutoCaptureScreen()));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Amount (UGX)'), '');
    await tester.pump();
    final sheet = find.byType(CaptureReviewSheet);
    final button = find.descendant(of: sheet, matching: find.byType(ActionButton));
    expect(tester.widget<ActionButton>(button).onPressed, isNull);
    expect(find.text('Enter the amount to confirm'), findsOneWidget, reason: 'says why');

    await tester.enterText(find.widgetWithText(TextField, 'Amount (UGX)'), '5,000');
    await tester.pump();
    expect(tester.widget<ActionButton>(button).onPressed, isNotNull);
    expect(find.text('Enter the amount to confirm'), findsNothing);
  });
}
