import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/bill.dart';
import 'package:money_track/services/alerts_service.dart';
import 'package:money_track/ui/widgets/alerts_bell.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/capture_test_helpers.dart';
import 'real_fonts.dart';
import 'test_theme.dart';

// Tests for AlertsService (which works out the current alerts and remembers
// which ones were dismissed) and AlertsBell (the Home app-bar icon with an
// unread-count badge). Bills due tomorrow are used to raise alerts, whose
// ids are "bill_<bill id>". Dismissals are kept in SharedPreferences, which
// is mocked empty before each test.

/// An unpaid bill due tomorrow, which raises one bill alert.
Bill _billDueSoon(String id) =>
    Bill(id: id, name: 'Water $id', amount: 54000, dueDate: DateTime.now().add(const Duration(days: 1)));

void main() {
  late Phone phone;

  setUpAll(loadRealFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async => phone.shutdown());

  group('AlertsService', () {
    test('counts alerts until they are dismissed', () async {
      phone = await Phone.boot();
      await phone.vm.addBill(_billDueSoon('b1'));
      await phone.vm.addBill(_billDueSoon('b2'));
      final alerts = AlertsService();
      await alerts.ready;

      expect(alerts.countFor(phone.vm), 2);
      await alerts.dismiss('bill_b1');
      expect(alerts.countFor(phone.vm), 1);
      expect(alerts.active(phone.vm).single.id, 'bill_b2');
    });

    test('dismissed alerts stay dismissed after the app restarts', () async {
      phone = await Phone.boot();
      await phone.vm.addBill(_billDueSoon('b1'));
      final first = AlertsService();
      await first.ready;
      await first.dismiss('bill_b1');

      // A new service reads the saved dismissals, as on the next launch.
      final afterRestart = AlertsService();
      await afterRestart.ready;
      expect(afterRestart.countFor(phone.vm), 0);
    });

    test('no alerts when the reminders are switched off', () async {
      phone = await Phone.boot();
      await phone.vm.addBill(_billDueSoon('b1'));
      await phone.vm.updateSettings(phone.vm.settings..billRemindersEnabled = false);
      final alerts = AlertsService();
      await alerts.ready;
      expect(alerts.countFor(phone.vm), 0);
    });
  });

  group('AlertsBell', () {
    /// Shows the bell with two bill alerts waiting and a stand-in /alerts
    /// page. Set-up that saves to storage runs in real time (runAsync).
    Future<AlertsService> pumpBell(WidgetTester tester) async {
      late AlertsService alerts;
      await tester.runAsync(() async {
        phone = await Phone.boot();
        await phone.vm.addBill(_billDueSoon('b1'));
        await phone.vm.addBill(_billDueSoon('b2'));
        alerts = AlertsService();
        await alerts.ready;
      });
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<TrackerViewModel>.value(value: phone.vm),
          ChangeNotifierProvider<AlertsService>.value(value: alerts),
        ],
        child: MaterialApp(
          theme: testAppTheme(),
          home: const Scaffold(body: Center(child: AlertsBell())),
          routes: {'/alerts': (_) => const Scaffold(body: Text('Alerts page'))},
        ),
      ));
      return alerts;
    }

    testWidgets('shows how many alerts are waiting', (tester) async {
      await pumpBell(tester);
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('Alerts, 2 unread'), findsOneWidget);
    });

    testWidgets('the badge counts down as alerts are dismissed, and goes at zero', (tester) async {
      final alerts = await pumpBell(tester);
      await tester.runAsync(() => alerts.dismiss('bill_b1'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await tester.runAsync(() => alerts.dismiss('bill_b2'));
      await tester.pump();
      expect(find.text('1'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.bySemanticsLabel('Alerts'), findsOneWidget);
    });

    testWidgets('opens the Alerts screen', (tester) async {
      await pumpBell(tester);
      await tester.tap(find.byType(AlertsBell));
      await tester.pumpAndSettle();
      expect(find.text('Alerts page'), findsOneWidget);
    });
  });
}
