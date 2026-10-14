import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/ui/widgets/action_button.dart';

import 'test_theme.dart';

// Tests for ActionButton, the app's button for actions that take a moment
// (saving, confirming). Its action returns a Future<bool>: while it runs the
// button shows a spinner (only after a short delay, so quick actions don't
// flicker); true shows a check and doneLabel, then calls onDone; false or an
// error puts the button back as it was.
void main() {
  /// Shows [button] alone, 300 wide, in the app's theme.
  Future<void> pump(WidgetTester tester, Widget button) => tester.pumpWidget(
        MaterialApp(theme: testAppTheme(), home: Scaffold(body: Center(child: SizedBox(width: 300, child: button)))),
      );

  testWidgets('spinner while working, then a check, then onDone', (tester) async {
    // The test decides when the "work" finishes by completing this.
    final work = Completer<bool>();
    var done = 0;
    await pump(
      tester,
      ActionButton(label: 'Save', doneLabel: 'Saved', onPressed: () => work.future, onDone: () => done++),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'no flash for quick actions');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    work.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(done, 0, reason: 'the check shows first');

    await tester.pump(const Duration(milliseconds: 700));
    expect(done, 1);
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget, reason: 'ready again');
  });

  testWidgets('a second tap while working is ignored', (tester) async {
    final work = Completer<bool>();
    var runs = 0;
    await pump(tester, ActionButton(label: 'Save', onPressed: () {
      runs++;
      return work.future;
    }));

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(ActionButton));
    await tester.pump();
    expect(runs, 1);
    work.complete(true);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('no check when the action reports it did not happen', (tester) async {
    await pump(tester, ActionButton(label: 'Save', doneLabel: 'Saved', onPressed: () async => false));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('an action that throws puts the button back, without a check', (tester) async {
    await pump(tester, ActionButton(label: 'Save', doneLabel: 'Saved', onPressed: () async => throw StateError('x')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('sinks slightly while held', (tester) async {
    await pump(tester, ActionButton(label: 'Save', onPressed: () async => true));
    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Save')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(scale(), 1);
  });

  testWidgets('disabled without an action', (tester) async {
    await pump(tester, const ActionButton(label: 'Save', onPressed: null));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
