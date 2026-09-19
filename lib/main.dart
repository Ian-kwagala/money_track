import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/money_repository.dart';
import 'ui/auth/lock_screen.dart';
import 'ui/auto_capture/auto_capture_screen.dart';
import 'ui/bills/bills_screen.dart';
import 'ui/dashboard/daily_spend_screen.dart';
import 'ui/goals/goals_screen.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/reports/reports_screen.dart';
import 'ui/settings/category_manager_screen.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/theme/app_theme.dart';
import 'viewmodels/tracker_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = MoneyRepository();
  runApp(MoneyTrackApp(repo: repo));
}

class MoneyTrackApp extends StatelessWidget {
  final MoneyRepository repo;

  const MoneyTrackApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TrackerViewModel(repo),
      child: Consumer<TrackerViewModel>(
        builder: (context, vm, _) => MaterialApp(
          title: 'MoneyTrack',
          debugShowCheckedModeBanner: false,
          theme: vm.initialized
              ? (vm.settings.darkMode ? AppTheme.dark() : AppTheme.light())
              : AppTheme.light(),
          routes: {
            '/daily': (_) => const DailySpendScreen(),
            '/recurring': (_) => const BillsScreen(),
            '/goals': (_) => const GoalsScreen(),
            '/categories': (_) => const CategoryManagerScreen(),
            '/capture': (_) => const AutoCaptureScreen(),
            '/analytics': (_) => const ReportsScreen(),
          },
          home: const _RootRouter(),
        ),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerViewModel>(
      builder: (context, vm, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _resolveChild(vm),
        );
      },
    );
  }

  Widget _resolveChild(TrackerViewModel vm) {
    if (!vm.initialized) {
      return const SplashScreen(key: ValueKey('splash'));
    }
    if (vm.needsOnboarding) {
      return const OnboardingScreen(key: ValueKey('onboarding'));
    }
    if (vm.isAppLocked && !vm.isUnlocked) {
      return const LockScreen(key: ValueKey('lock'));
    }
    return const HomeShell(key: ValueKey('home'));
  }
}
