import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/category.dart';
import 'package:money_track/models/frequency.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/ui/add_transaction/category_sheets.dart';
import 'package:money_track/ui/add_transaction/quick_add_sheet.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';

import '../capture/capture_test_helpers.dart';
import 'real_fonts.dart';
import 'test_theme.dart';

void main() {
  late Phone phone;

  setUpAll(loadRealFonts);
  tearDown(() async => phone.shutdown());

  /// Opens Quick add; [setup] runs on the fresh phone first.
  Future<void> openQuickAdd(WidgetTester tester, {Future<void> Function(TrackerViewModel vm)? setup}) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      await setup?.call(phone.vm);
    });
    await tester.pumpWidget(ChangeNotifierProvider<TrackerViewModel>.value(
      value: phone.vm,
      child: MaterialApp(
        theme: testAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const QuickAddSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder f) => find.descendant(of: find.byType(QuickAddSheet), matching: f);
  Finder inNew(Finder f) => find.descendant(of: find.byType(NewCategorySheet), matching: f);

  Future<void> typeAmount(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(inSheet(find.text(d)).last);
      await tester.pump();
    }
  }

  /// Saves and waits for the transaction to be stored and the sheet to close.
  Future<TxRecord> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Save transaction'));
      await until(() => phone.vm.transactions.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5)); // the Undo snackbar
    return phone.vm.transactions.single;
  }

  Future<void> tapFrequency(WidgetTester tester, String label) async {
    final chip = inSheet(find.text(label));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
  }

  testWidgets('what is missing shows inside the form, above the keypad, then clears itself', (tester) async {
    await openQuickAdd(tester);
    await tester.tap(find.text('Save transaction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final hint = find.text('Enter an amount');
    expect(hint, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: 'a snackbar would be hidden behind the sheet');
    expect(tester.getRect(hint).bottom, lessThan(tester.getRect(inSheet(find.text('1')).last).top));
    expect(tester.getRect(hint).top, greaterThan(tester.getRect(find.byType(QuickAddSheet)).top));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsNothing);
  });

  testWidgets('a new message replaces the old one and can be tapped away', (tester) async {
    await openQuickAdd(tester);
    await typeAmount(tester, '5000');
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a category'), findsOneWidget);

    await tester.tap(find.text('Pick a category'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a category'), findsNothing);
  });

  testWidgets('the grid ends in More and New; More lists every category', (tester) async {
    await openQuickAdd(tester);
    expect(inSheet(find.text('More')), findsOneWidget);
    expect(inSheet(find.text('New')), findsOneWidget);
    expect(inSheet(find.text('Water')), findsNothing, reason: 'not one of the first six');

    await tester.tap(inSheet(find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('All expense categories'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(CategoryPickerSheet), matching: find.text('Water')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPickerSheet), findsNothing);
    expect(inSheet(find.text('Water')), findsOneWidget, reason: 'the picked one joins the grid');

    await typeAmount(tester, '3000');
    final tx = await save(tester);
    expect(tx.categoryId, 'cat_expense_water');
  });

  testWidgets('the categories used most come first', (tester) async {
    await openQuickAdd(tester, setup: (vm) async {
      for (var i = 0; i < 3; i++) {
        await vm.addTransaction(TxRecord(
          id: 'w$i',
          type: TxType.expense,
          amount: 1000,
          walletId: vm.wallets.first.id,
          categoryId: 'cat_expense_water',
          dateTime: DateTime(2026, 10, 1 + i),
        ));
      }
    });
    expect(inSheet(find.text('Water')), findsOneWidget);
    expect(tester.getCenter(inSheet(find.text('Water'))).dx,
        lessThan(tester.getCenter(inSheet(find.text('Airtime & Data'))).dx));
  });

  testWidgets('categories someone made come before unused built-in ones', (tester) async {
    await openQuickAdd(tester, setup: (vm) async {
      // An id that sorts last, so the order isn't an accident of storage.
      await vm.addCategory(Category(id: 'cat_zz_salon', name: 'Salon', icon: 'content_cut'));
    });
    expect(tester.getCenter(inSheet(find.text('Salon'))).dx,
        lessThan(tester.getCenter(inSheet(find.text('Airtime & Data'))).dx));
  });

  testWidgets('New: name it, say how often, and it is picked and remembered', (tester) async {
    await openQuickAdd(tester);
    await tester.tap(inSheet(find.text('New')));
    await tester.pumpAndSettle();
    expect(find.text('New expense category'), findsOneWidget);

    await tester.enterText(inNew(find.byType(TextField)), 'Boda boda');
    await tester.pump();
    expect(inNew(find.byIcon(Icons.two_wheeler)), findsWidgets, reason: 'icon guessed from the name');
    await tester.tap(inNew(find.text('Weekly')));
    await tester.pump();
    expect(find.textContaining('Quick add will pick Weekly'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Create category'));
      await until(() => phone.vm.categories.any((c) => c.name == 'Boda boda'));
    });
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Added'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
    expect(find.byType(NewCategorySheet), findsNothing);
    expect(find.text('“Boda boda” added · Weekly'), findsOneWidget);

    final cat = phone.vm.categories.singleWhere((c) => c.name == 'Boda boda');
    expect(cat.type, TxType.expense);
    expect(cat.frequency, 'weekly');
    expect(cat.icon, 'two_wheeler');
    expect(cat.isBuiltIn, isFalse);

    await typeAmount(tester, '7000');
    final tx = await save(tester);
    expect(tx.categoryId, cat.id);
    expect(tx.frequency, Frequency.weekly);
    expect(tx.isRecurring, isTrue);
  });

  testWidgets('New needs a name', (tester) async {
    await openQuickAdd(tester);
    await tester.tap(inSheet(find.text('New')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create category'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name, e.g. Salon'), findsOneWidget);
    expect(find.byType(NewCategorySheet), findsOneWidget);
  });

  testWidgets('a name that is already there picks that one instead of a copy', (tester) async {
    await openQuickAdd(tester);
    final before = phone.vm.categories.length;
    await tester.tap(inSheet(find.text('New')));
    await tester.pumpAndSettle();
    await tester.enterText(inNew(find.byType(TextField)), ' food ');
    await tester.tap(find.text('Create category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Already there'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(phone.vm.categories.length, before);
    expect(find.textContaining('You already have “Food”'), findsOneWidget);
    await typeAmount(tester, '2000');
    expect((await save(tester)).categoryId, 'cat_expense_food');
  });

  group('a category someone made brings its usual frequency', () {
    Future<void> withSalon(TrackerViewModel vm) => vm.addCategory(Category(
          id: 'cat_salon',
          name: 'Salon',
          icon: 'content_cut',
          type: TxType.expense,
          frequency: 'monthly',
        ));

    testWidgets('picked: Monthly', (tester) async {
      await openQuickAdd(tester, setup: withSalon);
      await tester.tap(inSheet(find.text('Salon')));
      await tester.pump();
      await typeAmount(tester, '15000');
      expect((await save(tester)).frequency, Frequency.monthly);
    });

    testWidgets('then a built-in one: back to Once', (tester) async {
      await openQuickAdd(tester, setup: withSalon);
      await tester.tap(inSheet(find.text('Salon')));
      await tester.pump();
      await tester.tap(inSheet(find.text('Food')));
      await tester.pump();
      await typeAmount(tester, '15000');
      expect((await save(tester)).frequency, Frequency.once);
    });

    testWidgets('only the frequency row slides to show it; the form does not jump', (tester) async {
      await openQuickAdd(tester, setup: (vm) => vm.addCategory(Category(
            id: 'cat_dues',
            name: 'Club dues',
            icon: 'fitness_center',
            frequency: 'yearly',
          )));
      final foodY = tester.getTopLeft(inSheet(find.text('Food'))).dy;
      await tester.tap(inSheet(find.text('Club dues')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(inSheet(find.text('Food'))).dy, foodY);
      final yearly = tester.getRect(inSheet(find.text('Yearly')));
      expect(yearly.left, greaterThanOrEqualTo(0));
      expect(yearly.right, lessThanOrEqualTo(390));
    });

    testWidgets('a frequency picked by hand stays', (tester) async {
      await openQuickAdd(tester, setup: withSalon);
      await tapFrequency(tester, 'Weekly');
      await tester.tap(inSheet(find.text('Salon')));
      await tester.pump();
      await typeAmount(tester, '15000');
      expect((await save(tester)).frequency, Frequency.weekly);
    });
  });
}
