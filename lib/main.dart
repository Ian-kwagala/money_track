import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/money_repository.dart';
import 'services/cloud/announcement_service.dart';
import 'services/cloud/auth_service.dart';
import 'services/cloud/connectivity_service.dart';
import 'services/cloud/firebase_bootstrap.dart';
import 'services/cloud/sync_service.dart';
import 'services/shorebird_update_service.dart';
import 'ui/auth/lock_screen.dart';
import 'ui/auto_capture/auto_capture_screen.dart';
import 'ui/bills/bills_screen.dart';
import 'ui/dashboard/daily_spend_screen.dart';
import 'ui/debts/debts_screen.dart';
import 'ui/expenses/expenses_screen.dart';
import 'ui/goals/goals_screen.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/reports/reports_screen.dart';
import 'ui/settings/category_manager_screen.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/theme/app_theme.dart';
import 'viewmodels/tracker_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local-only and fast (no network). If Firebase isn't configured or fails,
  // the app runs exactly as before: offline on Hive, cloud UI hidden.
  await FirebaseBootstrap.init();

  final repo = MoneyRepository();
  final connectivity = ConnectivityService();
  final auth = AuthService();
  final sync = SyncService(repo: repo, auth: auth, connectivity: connectivity);
  final viewModel = TrackerViewModel(repo, onReady: sync.start);
  sync.onRemoteChangesApplied = viewModel.refreshFromStorage;

  final updateService = ShorebirdUpdateService();
  // Fire-and-forget: reads the installed patch number and, if a newer one
  // exists, downloads it in the background. Never blocks app startup and
  // never applies mid-session — see ShorebirdUpdateService for details.
  updateService.loadCurrentPatch();
  updateService.checkForUpdate();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: viewModel),
      ChangeNotifierProvider.value(value: updateService),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider(create: (_) => AnnouncementService()),
    ],
    child: const MoneyTrackApp(),
  ));
}

class MoneyTrackApp extends StatelessWidget {
  const MoneyTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
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
            '/transactions': (_) => const ExpensesScreen(),
            '/debts': (_) => const DebtsScreen(),
          },
          home: const _RootRouter(),
        ),
=======
    return Consumer<TrackerViewModel>(
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
>>>>>>> 2ef2dfaf7334db2cbbf13ff53669e62d330d6f69
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
