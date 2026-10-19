import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track_admin/pages/login_page.dart';
import 'package:money_track_admin/pages/shell.dart';

import 'helpers.dart';

void main() {
  setUpAll(loadRealFonts);

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('signs in an admin', (tester) async {
    final auth = FakeAdminAuth();
    await pumpAdmin(tester, auth: auth, db: await seededDb());
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Everything you need\nto run MoneyTrack.'), findsOneWidget, reason: 'the brand panel on wide screens');

    await tester.enterText(field('Email'), 'admin@moneytrack.app');
    await tester.enterText(field('Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('admin@moneytrack.app'), findsOneWidget, reason: 'in the account menu');
  });

  testWidgets('a wrong password is explained and nothing else happens', (tester) async {
    await pumpAdmin(tester, auth: FakeAdminAuth());
    await tester.enterText(field('Email'), 'admin@moneytrack.app');
    await tester.enterText(field('Password'), 'nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('the password can be shown while typing', (tester) async {
    await pumpAdmin(tester, auth: FakeAdminAuth());
    bool obscured() => tester.widget<TextField>(field('Password')).obscureText;
    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('Forgot password sends a reset link to the address typed', (tester) async {
    final auth = FakeAdminAuth();
    await pumpAdmin(tester, auth: auth);
    await tester.enterText(field('Email'), 'admin@moneytrack.app');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('admin@moneytrack.app'), findsOneWidget, reason: 'the email carries over');

    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(auth.resetsSentTo, ['admin@moneytrack.app']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('Open the link in the email'), findsOneWidget);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Forgot password needs a real email address first', (tester) async {
    final auth = FakeAdminAuth();
    await pumpAdmin(tester, auth: auth);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email'), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the email address of your admin account.'), findsOneWidget);
    expect(auth.resetsSentTo, isEmpty);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Enter the email address of your admin account.'), findsNothing, reason: 'errors clear');
  });

  testWidgets('an account without the admin role is turned away', (tester) async {
    final auth = FakeAdminAuth(accounts: {'user@example.com': ('pw-123456', false)})..signInAs('user@example.com');
    await pumpAdmin(tester, auth: auth);
    expect(find.text('This account isn\'t an admin'), findsOneWidget);
    expect(find.byType(AdminShell), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('phones get a single column with the logo above the form', (tester) async {
    await pumpAdmin(tester, auth: FakeAdminAuth(), size: const Size(390, 844));
    expect(find.text('Everything you need\nto run MoneyTrack.'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Admin console'), findsOneWidget);
  });
}
