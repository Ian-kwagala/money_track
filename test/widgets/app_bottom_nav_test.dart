import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/ui/widgets/app_bottom_nav.dart';

const _items = [
  AppNavItem(label: 'Home', icon: Icons.home_outlined),
  AppNavItem(label: 'Budgets', icon: Icons.account_balance_wallet_outlined),
  AppNavItem(label: 'Analytics', icon: Icons.pie_chart_outline),
  AppNavItem(label: 'Settings', icon: Icons.settings_outlined),
];

Finder _inNav(Type type) => find.descendant(of: find.byType(AppBottomNav), matching: find.byType(type));

/// The white bar (the first box drawn inside the nav).
Rect _bar(WidgetTester t) => t.getRect(_inNav(DecoratedBox).first);

/// The round button's tappable circle.
Rect _button(WidgetTester t) => t.getRect(_inNav(InkWell));

void main() {
  late List<int> selected;
  late int added;
  late int pageTaps;

  Future<void> pump(WidgetTester tester, {int index = 0, double bottomInset = 0}) async {
    selected = [];
    added = 0;
    pageTaps = 0;
    tester.view
      ..physicalSize = const Size(390, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 800), viewPadding: EdgeInsets.only(bottom: bottomInset)),
        child: Scaffold(
          body: Stack(
            children: [
              // The page under the bar, to check what taps reach it.
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => pageTaps++),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(
                  items: _items,
                  currentIndex: index,
                  onTabSelected: selected.add,
                  action: AppNavAction(
                    label: 'Add',
                    icon: Icons.add_rounded,
                    semanticLabel: 'Add transaction',
                    onPressed: () => added++,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  testWidgets('five items: four tabs with labels and the Add button in the middle', (tester) async {
    await pump(tester);
    for (final label in ['Home', 'Budgets', 'Add', 'Analytics', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }
    final xs = [for (final l in ['Home', 'Budgets', 'Add', 'Analytics', 'Settings']) tester.getCenter(find.text(l)).dx];
    expect(xs, orderedEquals([...xs]..sort()), reason: 'left to right in this order');
    expect(tester.getCenter(find.byIcon(Icons.add_rounded)).dx, closeTo(195, 0.5), reason: 'centred');
  });

  testWidgets('every label sits on the same line', (tester) async {
    await pump(tester);
    final ys = {for (final l in ['Home', 'Budgets', 'Add', 'Analytics', 'Settings']) tester.getCenter(find.text(l)).dy};
    expect(ys, hasLength(1));
  });

  testWidgets('the Add button rises above the bar\'s top edge', (tester) async {
    await pump(tester);
    final bar = _bar(tester);
    final button = _button(tester);
    expect(button.top, lessThan(bar.top));
    expect(button.bottom, greaterThan(bar.top));
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Analytics'));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    expect(selected, [2, 3]);
    expect(added, 0);
  });

  testWidgets('the button, its top edge above the bar, and its label all run the action', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    final button = _button(tester);
    await tester.tapAt(Offset(button.center.dx, button.top + 4));
    await tester.tap(find.text('Add'));
    expect(added, 3);
    expect(selected, isEmpty);
    expect(pageTaps, 0);
  });

  testWidgets('the clear strip beside the button doesn\'t swallow taps meant for the page', (tester) async {
    await pump(tester);
    final bar = _bar(tester);
    await tester.tapAt(Offset(40, bar.top - 4));
    expect(pageTaps, 1);
    expect(selected, isEmpty);
  });

  testWidgets('the bar runs behind the gesture area but keeps its tabs above it', (tester) async {
    await pump(tester, bottomInset: 34);
    final bar = _bar(tester);
    expect(bar.bottom, 800);
    expect(tester.getBottomLeft(find.text('Home')).dy, lessThan(800 - 34));
    expect(AppBottomNav.heightOf(tester.element(find.text('Home'))), AppBottomNav.barHeight + 34);
  });

  testWidgets('the selected tab is marked for screen readers; the button is labelled', (tester) async {
    await pump(tester, index: 1);
    expect(tester.getSemantics(find.text('Budgets')), matchesSemantics(
        isSelected: true, hasSelectedState: true, isButton: true, hasTapAction: true, hasFocusAction: true, label: 'Budgets', isFocusable: true));
    expect(tester.getSemantics(find.text('Home')), matchesSemantics(
        hasSelectedState: true, isButton: true, hasTapAction: true, hasFocusAction: true, label: 'Home', isFocusable: true));
    expect(find.bySemanticsLabel('Add transaction'), findsOneWidget);
  });

  testWidgets('no tab highlighted when the current page has no tab', (tester) async {
    await pump(tester, index: -1);
    for (final l in ['Home', 'Budgets', 'Analytics', 'Settings']) {
      expect(tester.widget<Text>(find.text(l)).style, isNull);
      final style = tester.widget<DefaultTextStyle>(
          find.ancestor(of: find.text(l), matching: find.byType(DefaultTextStyle)).first).style;
      expect(style.fontWeight, FontWeight.w500, reason: l);
    }
  });
}
