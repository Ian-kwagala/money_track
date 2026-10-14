import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/money_repository.dart';
import 'services/alerts_service.dart';
import 'services/capture/capture_service.dart';
import 'services/capture/sms_bridge.dart';
import 'services/cloud/announcement_service.dart';
import 'services/cloud/auth_service.dart';
import 'services/cloud/connectivity_service.dart';
import 'services/cloud/firebase_bootstrap.dart';
import 'services/cloud/sync_service.dart';
import 'services/shorebird_update_service.dart';
import 'ui/alerts/alerts_screen.dart';
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

/// App entry point. Builds the long-lived services, wires them together and
/// hands them to the widget tree through Provider.
///
/// Startup order matters:
/// 1. Firebase (optional), so the cloud services below know if they can work.
/// 2. The services are created here, but local storage isn't opened yet.
///    The splash screen calls TrackerViewModel.init, which opens Hive.
/// 3. Once Hive is open, the view model's onReady starts cloud sync and SMS
///    auto-capture in the background.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local-only and fast (no network). If Firebase isn't configured or fails,
  // the app runs exactly as before: offline on Hive, cloud UI hidden.
  await FirebaseBootstrap.init();

  final repo = MoneyRepository();
  final connectivity = ConnectivityService();
  final auth = AuthService();
  final sync = SyncService(repo: repo, auth: auth, connectivity: connectivity);
  // CaptureService needs the view model and the view model's onReady needs
  // CaptureService, so `capture` is declared late to break the cycle. It's
  // assigned before onReady can run.
  late final CaptureService capture;
  final viewModel = TrackerViewModel(repo, onReady: () => Future.wait([sync.start(), capture.start()]));
  capture = CaptureService(vm: viewModel, bridge: SmsBridge.platform());
  // When sync writes data pulled from the cloud into Hive, rebuild the UI.
  sync.onRemoteChangesApplied = viewModel.refreshFromStorage;

  final updateService = ShorebirdUpdateService();
  // Fire-and-forget: reads the installed patch number and, if a newer one
  // exists, downloads it in the background. Never blocks app startup and
  // never applies mid-session — see ShorebirdUpdateService for details.
  updateService.loadCurrentPatch();
  updateService.checkForUpdate();

  // Every service is a ChangeNotifier, so screens can watch the ones they
  // need. The last two are created lazily the first time a screen asks.
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: viewModel),
      ChangeNotifierProvider.value(value: updateService),
      ChangeNotifierProvider.value(value: connectivity),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider.value(value: capture),
      ChangeNotifierProvider(create: (_) => AnnouncementService()),
      ChangeNotifierProvider(create: (_) => AlertsService()),
    ],
    child: const MoneyTrackApp(),
  ));
}

/// The MaterialApp. Rebuilds when the view model changes so a dark-mode
/// toggle applies straight away.
///
/// The named routes are secondary screens opened from the home tabs,
/// alerts and settings with `Navigator.pushNamed`.
class MoneyTrackApp extends StatelessWidget {
  const MoneyTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          '/transactions': (_) => const ExpensesScreen(),
          '/debts': (_) => const DebtsScreen(),
          '/alerts': (_) => const AlertsScreen(),
        },
        home: const _RootRouter(),
      ),
    );
  }
}

/// Chooses the top-level screen from the app's state and cross-fades
/// between them:
/// splash (still loading) -> onboarding (first run) -> lock (PIN required)
/// -> home.
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

  // Each screen gets a distinct key so AnimatedSwitcher sees a new child and
  // animates the change.
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
