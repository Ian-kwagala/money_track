import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/services/alerts_service.dart';
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
import 'test_theme.dart';

// Widget tests for HomeShell, the screen with the bottom bar that holds
// Home, Budgets, Analytics and Settings. They check the bar, switching tabs,
// the Add button, the Home stats and the alerts bell.
void main() {
  late Phone phone;

  setUpAll(loadRealFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async => phone.shutdown());

  /// Shows HomeShell on a phone-sized screen with every provider the app
  /// gives it. Auth and sync are inert (no Firebase, sync disabled, offline).
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
        ChangeNotifierProvider(create: (_) => AlertsService()),
        ChangeNotifierProvider(create: (_) => ShorebirdUpdateService()),
      ],
      child: MaterialApp(
        theme: testAppTheme(),
        home: const HomeShell(),
        routes: {'/alerts': (_) => const AlertsScreen()},
      ),
    ));
    await tester.pumpAndSettle();
  }

  // A label inside the bottom bar, and which page the IndexedStack shows.
  // Page 3 is Alerts, which has no tab on phones; the bell opens it.
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

  testWidgets('after Quick add saves, its Undo snackbar sits just above the bar and goes after 4 seconds',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    final sheet = find.byType(QuickAddSheet);
    for (final d in '5000'.split('')) {
      await tester.tap(find.descendant(of: sheet, matching: find.text(d)).last);
      await tester.pump();
    }
    await tester.tap(find.descendant(of: sheet, matching: find.text('Food')));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save transaction'));
      await until(() => phone.vm.transactions.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();

    final snack = find.byType(SnackBar);
    expect(find.text('Saved · UGX 5,000 · Food'), findsOneWidget);
    expect(tester.getRect(snack).bottom, lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBottomNav)).dy),
        reason: 'above the bar and its raised Add button, not over them');
    expect(tester.getRect(snack).bottom, greaterThan(tester.getTopLeft(find.byType(AppBottomNav)).dy - 40),
        reason: 'right above it');

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(snack, findsNothing, reason: 'goes by itself even though it has Undo');
    expect(phone.vm.transactions, hasLength(1), reason: 'and that is not an Undo');
  });

  testWidgets('pages still end where the bar starts', (tester) async {
    await pumpShell(tester);
    final pageBottom = tester.getBottomLeft(find.byType(IndexedStack)).dy;
    final barTop = tester.getTopLeft(find.byType(AppBottomNav)).dy;
    expect(pageBottom, barTop + AppBottomNav.overhang, reason: 'content runs under the strip beside Add, as before');
  });

  testWidgets('Home: no spending score; saved this month and average daily spend instead', (tester) async {
    await pumpShell(tester);
    expect(find.text('Spending score'), findsNothing);
    // Every tab is built at once, so "one" also means Analytics no longer has them.
    expect(find.text('Saved this month'), findsOneWidget);
    expect(find.text('Avg daily spend'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.descendant(of: find.byType(ListView), matching: find.text('Alerts')), findsNothing,
        reason: 'the bell replaced the shortcut');
  });

  testWidgets('the bell next to the dark-mode button opens Alerts, with a way back', (tester) async {
    await pumpShell(tester);
    final bell = find.byIcon(Icons.notifications_outlined);
    expect(bell, findsOneWidget);
    expect(tester.getCenter(bell).dx, lessThan(tester.getCenter(find.byIcon(Icons.dark_mode_outlined)).dx));

    await tester.tap(bell);
    await tester.pumpAndSettle();
    final pushed = find.byType(AlertsScreen).last;
    expect(find.descendant(of: pushed, matching: find.byIcon(Icons.chevron_left)), findsOneWidget);
    await tester.tap(find.descendant(of: pushed, matching: find.byIcon(Icons.chevron_left)));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(page(tester), 0);
  });
}
