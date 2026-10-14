import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:money_track/ui/add_transaction/quick_add_sheet.dart';
import 'package:money_track/ui/widgets/receipt_picker.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:provider/provider.dart';

import '../capture/capture_test_helpers.dart';
import 'real_fonts.dart';
import 'test_theme.dart';

/// A 1×1 PNG, standing in for a receipt photo.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

// Widget tests for the quick-add sheet: Save's checks and Undo, and the
// receipt picker (gallery, camera, view, replace, remove, refused
// permission). The image picker and the documents folder are swapped for
// fakes through the Receipts hooks, and put back after each test.
void main() {
  late Phone phone;

  /// Stands in for the app's documents folder, where receipts are copied.
  late Directory docs;

  // The real hooks, restored in tearDown.
  final realPick = Receipts.pick;
  final realDocuments = Receipts.documents;

  /// Every source (camera or gallery) the fake picker was asked to use.
  final picked = <ImageSource>[];

  setUpAll(loadRealFonts);
  tearDown(() async {
    Receipts.pick = realPick;
    Receipts.documents = realDocuments;
    picked.clear();
    await phone.shutdown();
  });

  /// Boots a phone, installs the fake picker and opens the sheet the way
  /// the app does, as a modal bottom sheet.
  Future<void> openQuickAdd(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      phone = await Phone.boot();
      docs = await Directory.systemTemp.createTemp('mt_docs');
    });
    Receipts.documents = () async => docs;
    // The fake picker writes the PNG outside docs, like the real picker's
    // temporary file, so the test can check the app copies it in.
    Receipts.pick = (source) async {
      picked.add(source);
      final f = File('${docs.path}/../picker_${DateTime.now().microsecondsSinceEpoch}.png')..writeAsBytesSync(_png);
      return XFile(f.path);
    };
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

  /// The receipt control sits low in the sheet's scrolling part.
  Future<Finder> receiptControl(WidgetTester tester, String label) async {
    final f = find.text(label);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    return f;
  }

  /// Types [digits] by tapping the sheet's number pad.
  Future<void> typeAmount(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(inSheet(find.text(d)).last);
      await tester.pump();
    }
  }

  testWidgets('Save says what is missing instead of doing nothing', (tester) async {
    await openQuickAdd(tester);
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);

    await typeAmount(tester, '5000');
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a category'), findsOneWidget);
    expect(phone.vm.transactions, isEmpty);
    expect(find.byType(QuickAddSheet), findsOneWidget, reason: 'still open');
  });

  testWidgets('Save shows a check, closes the sheet and offers Undo', (tester) async {
    await openQuickAdd(tester);
    await typeAmount(tester, '5000');
    await tester.tap(inSheet(find.text('Food')));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Save transaction'));
      await until(() => phone.vm.transactions.isNotEmpty);
    });
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsOneWidget, reason: 'the check mark');
    final tx = phone.vm.transactions.single;
    expect(tx.amount, 5000);
    expect(tx.categoryId, 'cat_expense_food');

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsNothing);
    expect(find.textContaining('Saved · UGX 5,000 · Food'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await until(() => phone.vm.transactions.isEmpty);
    });
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a receipt from the gallery is kept with the transaction', (tester) async {
    await openQuickAdd(tester);
    // Real time: attaching copies a file.
    final attach = await receiptControl(tester, 'Attach receipt');
    await tester.runAsync(() => tester.tap(attach));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose from gallery'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(picked, [ImageSource.gallery]);
    expect(find.text('Receipt attached · tap to view'), findsOneWidget);

    await typeAmount(tester, '12000');
    await tester.tap(inSheet(find.text('Food')));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save transaction'));
      await until(() => phone.vm.transactions.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();

    final path = phone.vm.transactions.single.receiptPath!;
    expect(path, startsWith('${docs.path}/receipts/'));
    expect(File(path).existsSync(), isTrue, reason: 'copied out of the picker\'s temporary file');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an attached receipt can be viewed, replaced with a photo, or removed', (tester) async {
    await openQuickAdd(tester);
    final attach = await receiptControl(tester, 'Attach receipt');
    await tester.runAsync(() => tester.tap(attach));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose from gallery'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.tap(await receiptControl(tester, 'Receipt attached · tap to view'));
    await tester.pumpAndSettle();
    expect(find.text('View receipt'), findsOneWidget);
    expect(find.text('Take a new photo'), findsOneWidget);
    await tester.tap(find.text('View receipt'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final attached = await receiptControl(tester, 'Receipt attached · tap to view');
    await tester.runAsync(() => tester.tap(attached));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Take a new photo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(picked, [ImageSource.gallery, ImageSource.camera]);

    await tester.tap(await receiptControl(tester, 'Receipt attached · tap to view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Attach receipt'), findsOneWidget);
  });

  testWidgets('a refused camera permission is explained', (tester) async {
    await openQuickAdd(tester);
    // The error image_picker reports when camera access is denied.
    Receipts.pick = (_) async => throw PlatformException(code: 'camera_access_denied');
    final attach = await receiptControl(tester, 'Attach receipt');
    await tester.runAsync(() => tester.tap(attach));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Take a photo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera permission is off'), findsOneWidget);
    expect(find.text('Attach receipt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
