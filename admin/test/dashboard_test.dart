import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track_admin/pages/change_password_dialog.dart';
import 'package:money_track_admin/pages/user_detail_page.dart';

import 'helpers.dart';

void main() {
  setUpAll(loadRealFonts);

  const admin = 'admin@moneytrack.app';

  Future<FakeAdminAuth> signedIn(WidgetTester tester, {Size size = const Size(1440, 900)}) async {
    final auth = FakeAdminAuth()..signInAs(admin);
    await pumpAdmin(tester, auth: auth, db: await tester.runAsync(seededDb), size: size);
    return auth;
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byType(ChangePasswordDialog), matching: f);

  Future<void> openChangePassword(WidgetTester tester) async {
    await tester.tap(find.text(admin));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordDialog), findsOneWidget);
  }

  Future<void> fill(WidgetTester tester, String current, String next, String confirm) async {
    await tester.enterText(inDialog(find.widgetWithText(TextField, 'Current password')), current);
    await tester.enterText(inDialog(find.widgetWithText(TextField, 'New password')), next);
    await tester.enterText(inDialog(find.widgetWithText(TextField, 'Confirm new password')), confirm);
    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Change password')));
    await tester.pumpAndSettle();
  }

  testWidgets('Overview shows the totals from the database', (tester) async {
    await signedIn(tester);
    expect(find.text('Overview'), findsWidgets);
    String kpi(String label) {
      final card = find.ancestor(of: find.text(label), matching: find.byType(Card)).first;
      final texts = find.descendant(of: card, matching: find.byType(Text)).evaluate();
      return texts.map((e) => (e.widget as Text).data).join('|');
    }

    expect(kpi('Total users'), contains('|3|'));
    expect(kpi('Active this week'), contains('|2|'));
    expect(kpi('New this month'), contains('|2|'));
    expect(kpi('Transactions logged'), contains('|62|'));
    expect(kpi('Live announcements'), contains('|1|'));
    expect(find.text('2 of 3'), findsNWidgets(2), reason: 'engagement: active this week, joined this month');
    expect(find.text('3 of 3'), findsOneWidget, reason: 'engagement: active this month');
    expect(find.text('Ian Mufasa'), findsOneWidget, reason: 'recent sign-ups');
  });

  testWidgets('a recent sign-up opens their details inside the dashboard, and the visit is logged', (tester) async {
    await signedIn(tester);
    await tester.tap(find.text('Ian Mufasa'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailPage), findsOneWidget);
    expect(find.text('Users'), findsWidgets, reason: 'the sidebar is still there');
    expect(find.textContaining('This visit was recorded'), findsOneWidget);
    expect(find.text('UGX 199,000'), findsOneWidget, reason: 'wallet balance');
    expect(find.text('Fuel'), findsOneWidget, reason: 'transaction category');
    expect(find.text('−UGX 10,000'), findsOneWidget);
    expect(find.text('+UGX 460,000'), findsOneWidget);

    await tester.tap(find.text('All users'));
    await tester.pumpAndSettle();
    expect(find.byType(UserDetailPage), findsNothing);
    expect(find.text('Search by email'), findsOneWidget);
  });

  testWidgets('Users lists everyone and search narrows by email', (tester) async {
    await signedIn(tester);
    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(find.text('Ian Mufasa'), findsOneWidget);
    expect(find.text('Grace Akello'), findsOneWidget);
    expect(find.text('No name'), findsOneWidget, reason: 'peter has no display name');
    expect(find.text('3 users'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Search by email'), 'Grace');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Grace Akello'), findsOneWidget);
    expect(find.text('Ian Mufasa'), findsNothing);
    expect(find.text('1 match'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Search by email'), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No one matches "zzz"'), findsOneWidget);
  });

  testWidgets('a new announcement is saved with what was chosen', (tester) async {
    await signedIn(tester);
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    expect(find.text('Custom categories are here'), findsOneWidget);

    await tester.tap(find.text('New announcement').first);
    await tester.pumpAndSettle();
    final publish = find.widgetWithText(FilledButton, 'Publish');
    expect(tester.widget<FilledButton>(publish).onPressed, isNull, reason: 'needs a title');
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Maintenance tonight');
    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Backup pauses 10-11 pm.');
    await tester.tap(find.text('Warning').last);
    await tester.pump();
    expect(find.text('Backup pauses 10-11 pm.'), findsWidgets, reason: 'the preview updates');
    await tester.tap(publish);
    await tester.pumpAndSettle();

    expect(find.text('Maintenance tonight'), findsOneWidget);
    expect(find.text('Published. It shows in the app now.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  group('Change password', () {
    testWidgets('changes it after checking the current one', (tester) async {
      final auth = await signedIn(tester);
      await openChangePassword(tester);
      await fill(tester, 'correct-horse', 'battery-staple-9', 'battery-staple-9');
      expect(find.byType(ChangePasswordDialog), findsNothing);
      expect(find.text('Password changed.'), findsOneWidget);
      expect(auth.passwordOf(admin), 'battery-staple-9');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a wrong current password is explained', (tester) async {
      final auth = await signedIn(tester);
      await openChangePassword(tester);
      await fill(tester, 'guess', 'battery-staple-9', 'battery-staple-9');
      expect(find.text('Your current password is incorrect.'), findsOneWidget);
      expect(auth.passwordOf(admin), 'correct-horse');
    });

    testWidgets('checks the new password before asking', (tester) async {
      final auth = await signedIn(tester);
      await openChangePassword(tester);
      await fill(tester, 'correct-horse', 'short', 'short');
      expect(find.text('The new password needs at least 8 characters.'), findsOneWidget);
      await fill(tester, 'correct-horse', 'battery-staple-9', 'battery-staple-8');
      expect(find.text('The new passwords don\'t match.'), findsOneWidget);
      await fill(tester, 'correct-horse', 'correct-horse', 'correct-horse');
      expect(find.text('The new password must be different from the current one.'), findsOneWidget);
      expect(auth.passwordOf(admin), 'correct-horse');
    });

    testWidgets('a forgotten current password can be reset by email', (tester) async {
      final auth = await signedIn(tester);
      await openChangePassword(tester);
      await tester.tap(find.text('Forgot it? Email me a reset link'));
      await tester.pumpAndSettle();
      expect(auth.resetsSentTo, [admin]);
      expect(find.text('We sent a reset link to $admin.'), findsOneWidget);
    });
  });

  testWidgets('Sign out asks first, then returns to the login', (tester) async {
    final auth = await signedIn(tester);
    await tester.tap(find.text(admin));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(auth.current, isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('narrow windows get a menu button instead of the sidebar', (tester) async {
    await signedIn(tester, size: const Size(390, 844));
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    expect(find.text('Custom categories are here'), findsOneWidget);
  });
}
