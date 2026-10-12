import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/ui/auto_capture/check_message_sheet.dart';

Future<void> _pumpSheet(WidgetTester tester) =>
    tester.pumpWidget(const MaterialApp(home: Scaffold(body: CheckMessageSheet())));

void main() {
  testWidgets('shows what a pasted message says', (tester) async {
    await _pumpSheet(tester);
    await tester.enterText(find.byType(TextField),
        'SENT UGX 21,000 to GRACE AKELLO on 256700345. Fee UGX 500.0 Bal UGX 11,450. TID 157700004.');
    await tester.pump();

    expect(find.text('Sent · UGX 21,000'), findsOneWidget);
    expect(find.text('Airtel Money'), findsOneWidget);
    expect(find.text('Grace Akello'), findsOneWidget);
    expect(find.text('UGX 500'), findsOneWidget);
    expect(find.text('UGX 11,450'), findsOneWidget);
    expect(find.text('157700004'), findsOneWidget);
  });

  testWidgets('says so when a message is not a money message', (tester) async {
    await _pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'See you at 6pm');
    await tester.pump();

    expect(find.textContaining('Not recognised'), findsOneWidget);
  });

  testWidgets('shows nothing until something is entered', (tester) async {
    await _pumpSheet(tester);
    expect(find.textContaining('Not recognised'), findsNothing);
    expect(find.textContaining(' · UGX'), findsNothing);
  });
}
