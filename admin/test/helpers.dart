import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track_admin/main.dart';
import 'package:money_track_admin/services.dart';

/// Loads Roboto and the Material icons from the Flutter SDK so screens lay
/// out as they do in a browser (the test font draws every glyph as a box).
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

class _Person {
  _Person(this.uid, this.password, this.isAdmin);
  final String uid;
  String password;
  final bool isAdmin;
}

/// Stands in for Firebase Auth: a few accounts, and a record of what was
/// asked of it.
class FakeAdminAuth implements AdminAuth {
  FakeAdminAuth({Map<String, (String, bool)> accounts = const {'admin@moneytrack.app': ('correct-horse', true)}}) {
    var n = 0;
    for (final MapEntry(key: email, value: (password, isAdmin)) in accounts.entries) {
      _people[email] = _Person('uid${n++}', password, isAdmin);
    }
  }

  final _people = <String, _Person>{};
  final _changes = StreamController<AdminAccount?>.broadcast();
  AdminAccount? current;
  final resetsSentTo = <String>[];

  String passwordOf(String email) => _people[email]!.password;

  @override
  Stream<AdminAccount?> accountChanges() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final p = _people[email.trim()];
    if (p == null || p.password != password) throw const AdminAuthException('Email or password is incorrect.');
    current = AdminAccount(uid: p.uid, email: email.trim(), isAdmin: p.isAdmin);
    _changes.add(current);
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetsSentTo.add(email.trim());

  @override
  Future<void> changePassword({required String current, required String next}) async {
    final p = _people[this.current!.email]!;
    if (p.password != current) throw const AdminAuthException('Your current password is incorrect.');
    p.password = next;
  }

  @override
  Future<void> signOut() async {
    current = null;
    _changes.add(null);
  }

  /// Starts signed in, as [email].
  void signInAs(String email) {
    final p = _people[email]!;
    current = AdminAccount(uid: p.uid, email: email, isAdmin: p.isAdmin);
  }
}

/// A database with three users, one with backed-up records, and one live
/// announcement.
Future<FakeFirebaseFirestore> seededDb({DateTime? now}) async {
  final db = FakeFirebaseFirestore();
  now ??= DateTime.now();
  Timestamp ago(Duration d) => Timestamp.fromDate(now!.subtract(d));
  final users = db.collection('users');
  await users.doc('u1').set({
    'uid': 'u1',
    'email': 'iankwagala2022@gmail.com',
    'displayName': 'Ian Mufasa',
    'phone': '+256 700 000000',
    'occupation': 'Engineer',
    'incomeType': 'salary',
    'currencyCode': 'UGX',
    'platform': 'android',
    'createdAt': ago(const Duration(days: 2)),
    'lastSeenAt': ago(const Duration(hours: 3)),
    'counts': {'wallets': 3, 'transactions': 17, 'budgets': 1, 'savingsGoals': 0, 'bills': 0, 'debts': 0},
  });
  await users.doc('u2').set({
    'uid': 'u2',
    'email': 'grace@example.com',
    'displayName': 'Grace Akello',
    'currencyCode': 'UGX',
    'platform': 'android',
    'createdAt': ago(const Duration(days: 12)),
    'lastSeenAt': ago(const Duration(days: 1)),
    'counts': {'transactions': 40},
  });
  await users.doc('u3').set({
    'uid': 'u3',
    'email': 'peter@example.com',
    'displayName': '',
    'currencyCode': 'UGX',
    'platform': 'android',
    'createdAt': ago(const Duration(days: 60)),
    'lastSeenAt': ago(const Duration(days: 20)),
    'counts': {'transactions': 5},
  });
  Map<String, dynamic> record(Map<String, dynamic> data) =>
      {'data': data, 'deleted': false, 'updatedAtMs': now!.millisecondsSinceEpoch};
  final u1 = users.doc('u1');
  await u1.collection('wallets').doc('w1').set(record({'name': 'Airtel Money', 'currentBalance': 199000}));
  await u1.collection('wallets').doc('w2').set(record({'name': 'Cash', 'currentBalance': 445000}));
  await u1.collection('categories').doc('cat_fuel').set(record({'name': 'Fuel'}));
  await u1.collection('transactions').doc('t1').set(record({
    'type': 'expense',
    'amount': 10000,
    'categoryId': 'cat_fuel',
    'note': 'Shell Kira Road',
    'dateTime': ago(const Duration(hours: 5)),
  }));
  await u1.collection('transactions').doc('t2').set(record({
    'type': 'income',
    'amount': 460000,
    'categoryId': 'cat_salary',
    'note': '',
    'dateTime': ago(const Duration(days: 1)),
  }));
  await db.collection('announcements').add({
    'title': 'Custom categories are here',
    'body': 'Tap New in Quick add to make your own.',
    'level': 'info',
    'active': true,
    'createdAt': ago(const Duration(days: 1)),
    'createdBy': 'admin@moneytrack.app',
  });
  return db;
}

/// Runs the dashboard on a desktop-sized window (or [size]).
Future<void> pumpAdmin(
  WidgetTester tester, {
  required FakeAdminAuth auth,
  FirebaseFirestore? db,
  Size size = const Size(1440, 900),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final firestore = db ?? FakeFirebaseFirestore();
  await tester.pumpWidget(AdminApp(
    googleFonts: false,
    services: (child) => AdminServices(auth: auth, db: firestore, projectId: 'moneytracker-cb825', child: child),
  ));
  await tester.pumpAndSettle();
}
