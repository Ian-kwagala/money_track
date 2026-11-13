import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:money_track/ui/theme/app_theme.dart';
import 'package:money_track/ui/widgets/skeleton/skeleton_loading.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';
import 'package:money_track/data/money_repository.dart';

void main() {
  group('Skeleton Loading Widgets', () {
    testWidgets('ShimmerLoading renders child correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              child: Text('Loading placeholder'),
            ),
          ),
        ),
      );

      expect(find.text('Loading placeholder'), findsOneWidget);
    });

    testWidgets('DashboardSkeleton renders all placeholder components', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(googleFonts: false),
          home: const Scaffold(
            body: DashboardSkeleton(),
          ),
        ),
      );

      // Verify skeleton elements are present in the widget tree.
      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(SkeletonCard), findsWidgets);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(SkeletonLine), findsWidgets);
    });

    testWidgets('SkeletonLoadingScreen renders with dark theme without errors', (tester) async {
      // Mock repository and view model.
      final repo = MoneyRepository();
      final vm = TrackerViewModel(repo);

      await tester.pumpWidget(
        ChangeNotifierProvider<TrackerViewModel>.value(
          value: vm,
          child: MaterialApp(
            theme: AppTheme.dark(googleFonts: false),
            home: const SkeletonLoadingScreen(),
          ),
        ),
      );

      expect(find.byType(SkeletonLoadingScreen), findsOneWidget);
      expect(find.byType(DashboardSkeleton), findsOneWidget);
    });
  });
}
