import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/services/cloud/announcement_service.dart';
import 'package:money_track/services/cloud/auth_service.dart';
import 'package:money_track/services/cloud/connectivity_service.dart';
import 'package:money_track/services/cloud/sync_service.dart';
import 'package:money_track/services/shorebird_update_service.dart';
import 'package:money_track/ui/add_transaction/quick_add_sheet.dart';
import 'package:money_track/ui/alerts/alerts_screen.dart';
import 'package:money_track/ui/home_shell.dart';
import 'package:money_track/ui/widgets/app_bottom_nav.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/capture_test_helpers.dart';
import 'real_fonts.dart';

void main() {
  late Phone phone;

  setUpAll(loadRealFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async => phone.shutdown());

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      // Skip the one-time prompts Home shows on first open.
      phone.vm.currentUser.dateOfBirth = DateTime(1995);
      await phone.vm.saveUser(phone.vm.currentUser);
      await phone.vm.updateSettings(phone.vm.settings..dailyBudget = 20000);
    });
    final auth = AuthService();
    final connectivity = ConnectivityService.manual(online: false);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<TrackerViewModel>.value(value: phone.vm),
        ChangeNotifierProvider<CaptureService>.value(value: phone.capture),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ChangeNotifierProvider(
            create: (_) => SyncService(repo: phone.vm.repo, auth: auth, connectivity: connectivity, enabled: false)),
        ChangeNotifierProvider(create: (_) => AnnouncementService()),
        ChangeNotifierProvider(create: (_) => ShorebirdUpdateService()),
      ],
      child: MaterialApp(
        home: const HomeShell(),
        routes: {'/alerts': (_) => const AlertsScreen()},
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder inNav(String label) => find.descendant(of: find.byType(AppBottomNav), matching: find.text(label));
  int page(WidgetTester tester) => tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

  testWidgets('phones get the new bar: four tabs around Add, no floating button', (tester) async {
    await pumpShell(tester);
    for (final label in ['Home', 'Budgets', 'Add', 'Analytics', 'Settings']) {
      expect(inNav(label), findsOneWidget, reason: label);
    }
    expect(inNav('Alerts'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing, reason: 'the old floating + button is gone');
  });

  testWidgets('tabs switch pages; Add opens the quick-add sheet', (tester) async {
    await pumpShell(tester);
    expect(page(tester), 0);

    await tester.tap(inNav('Analytics'));
    await tester.pumpAndSettle();
    expect(page(tester), 2);

    await tester.tap(inNav('Settings'));
    await tester.pumpAndSettle();
    expect(page(tester), 4);

    await tester.tap(inNav('Budgets'));
    await tester.pumpAndSettle();
    expect(page(tester), 1);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);
  });

  testWidgets('Alerts opens from the Home shortcuts, with a way back', (tester) async {
    await pumpShell(tester);
    final shortcut = find.descendant(of: find.byType(ListView), matching: find.text('Alerts'));
    await tester.tap(shortcut.first);
    await tester.pumpAndSettle();

    final pushed = find.byType(AlertsScreen).last;
    expect(find.descendant(of: pushed, matching: find.byIcon(Icons.chevron_left)), findsOneWidget);
    await tester.tap(find.descendant(of: pushed, matching: find.byIcon(Icons.chevron_left)));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(page(tester), 0);
  });
}
