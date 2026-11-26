import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/format/money_format.dart';
import '../viewmodels/tracker_view_model.dart';

/// Platform abstraction for delivering local push notifications so the logic
/// can be unit-tested without native Android channels.
abstract class NotificationBridge {
  /// Requests notification permission if the platform requires it.
  Future<void> requestPermission();

  /// Posts a local system notification with [id], [title], and [body].
  Future<void> show({required int id, required String title, required String body});
}

/// Default bridge: invokes `money_track/notifications` on Android and is a
/// safe no-op on platforms that do not register that native channel.
class PlatformNotificationBridge implements NotificationBridge {
  static const _channel = MethodChannel('money_track/notifications');

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> requestPermission() async {
    if (!_isAndroid) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Never block app startup if permission checks aren't available.
    }
  }

  @override
  Future<void> show({required int id, required String title, required String body}) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('showBudgetAlert', {
        'id': id,
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('Budget notification failed: $e');
    }
  }
}

/// Watches [TrackerViewModel] and fires push notifications when this month's
/// expenses cross 80% or 100% of the user's monthly spending limit.
///
/// Each threshold fires at most once per calendar month (tracked in
/// [SharedPreferences]) and resets automatically if spending drops back below
/// the threshold (for example, if the user raises their limit or deletes a
/// transaction).
class BudgetNotificationService {
  static const int idWarning80 = 4300;
  static const int idExceeded100 = 4301;

  final TrackerViewModel vm;
  final NotificationBridge bridge;
  final DateTime Function() _now;

  bool _started = false;
  Future<void>? _inFlight;
  bool _pending = false;

  BudgetNotificationService({
    required this.vm,
    NotificationBridge? bridge,
    DateTime Function()? clock,
  })  : bridge = bridge ?? PlatformNotificationBridge(),
        _now = clock ?? DateTime.now;

  /// Begins listening to [vm] and runs an immediate threshold check.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await bridge.requestPermission();
    vm.addListener(_onModelChanged);
    await checkNow();
  }

  void _onModelChanged() {
    checkNow();
  }

  /// Evaluates the current month's spending against [TrackerViewModel.effectiveMonthlyLimit]
  /// and sends a 100% or 80% notification if newly crossed.
  ///
  /// Concurrent calls coalesce cleanly so rapid transaction writes never drop
  /// a threshold crossing.
  Future<void> checkNow() {
    if (_inFlight != null) {
      _pending = true;
      return _inFlight!;
    }
    _inFlight = _runLoop();
    return _inFlight!;
  }

  Future<void> _runLoop() async {
    try {
      do {
        _pending = false;
        await _evaluate();
      } while (_pending);
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _evaluate() async {
    final s = vm.settings;
    if (!s.notificationsEnabled || !s.budgetWarningsEnabled) return;

    final limit = vm.effectiveMonthlyLimit;
    if (limit <= 0) return;

    final now = _now();
    final monthStart = DateTime(now.year, now.month, 1);
    final spent = vm.spentTotal(monthStart, now);
    final ratio = spent / limit;
    final pct = (ratio * 100).round();
    final symbol = s.currencySymbol;

    final prefs = await SharedPreferences.getInstance();
    final key80 = _prefKey(now, 80);
    final key100 = _prefKey(now, 100);

    // Reset flags if the user raised their limit or removed expenses.
    if (ratio < 0.8 && (prefs.getBool(key80) ?? false)) {
      await prefs.setBool(key80, false);
    }
    if (ratio < 1.0 && (prefs.getBool(key100) ?? false)) {
      await prefs.setBool(key100, false);
    }

    if (ratio >= 1.0) {
      if (!(prefs.getBool(key100) ?? false)) {
        await prefs.setBool(key100, true);
        await prefs.setBool(key80, true);
        await bridge.show(
          id: idExceeded100,
          title: 'Monthly spending limit exceeded',
          body:
              'You have spent ${MoneyFormat.money(spent, symbol: symbol)} of your ${MoneyFormat.money(limit, symbol: symbol)} monthly limit ($pct%).',
        );
      }
    } else if (ratio >= 0.8) {
      if (!(prefs.getBool(key80) ?? false)) {
        await prefs.setBool(key80, true);
        await bridge.show(
          id: idWarning80,
          title: '80% of monthly spending limit reached',
          body:
              'You have spent ${MoneyFormat.money(spent, symbol: symbol)} of your ${MoneyFormat.money(limit, symbol: symbol)} monthly limit ($pct%).',
        );
      }
    }
  }

  static String _prefKey(DateTime now, int threshold) =>
      'budget_limit_notif_${now.year}_${now.month}_$threshold';

  void dispose() {
    if (_started) {
      vm.removeListener(_onModelChanged);
      _started = false;
    }
  }
}
