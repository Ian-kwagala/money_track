import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../ui/format/money_format.dart';
import '../ui/theme/app_theme.dart';
import '../viewmodels/tracker_view_model.dart';

/// One alert as shown on the Alerts screen.
class AlertItem {
  /// Stable ID that encodes what the alert is about (and, for time-bound
  /// alerts, the day or week), so a dismissal sticks to exactly this alert.
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;

  /// Used to sort the list; for alerts that aren't tied to one moment it's
  /// an offset from now that sets their position.
  final DateTime when;

  const AlertItem({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.when,
  });
}

/// The alerts on the Alerts screen, and the count on Home's bell. Alerts
/// are worked out from the user's data each time; the ones the user
/// dismissed are remembered on the phone so they stay dismissed.
class AlertsService extends ChangeNotifier {
  AlertsService({DateTime Function()? clock}) : _now = clock ?? DateTime.now {
    ready = _load();
  }

  final DateTime Function() _now;
  static const _prefsKey = 'dismissed_alerts';

  /// Oldest are dropped past this; alert ids carry dates, so old ones never
  /// come back anyway.
  static const _keepDismissed = 300;

  final _dismissed = <String>[];

  /// Completes once dismissed alerts have been read from storage.
  late final Future<void> ready;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissed.addAll(prefs.getStringList(_prefsKey) ?? const []);
    notifyListeners();
  }

  /// Alerts still waiting for the user, newest first.
  List<AlertItem> active(TrackerViewModel vm) =>
      build(vm, vm.settings.currencySymbol, _now()).where((a) => !_dismissed.contains(a.id)).toList();

  /// The number on the bell icon.
  int countFor(TrackerViewModel vm) => active(vm).length;

  /// Hides [id] for good, remembering it in SharedPreferences.
  Future<void> dismiss(String id) async {
    if (_dismissed.contains(id)) return;
    _dismissed.add(id);
    if (_dismissed.length > _keepDismissed) _dismissed.removeRange(0, _dismissed.length - _keepDismissed);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _dismissed);
  }

  /// Every alert that currently applies, dismissed or not, newest first.
  /// Each kind is gated by its toggle in [AppSettings]. Static and pure (no
  /// stored state), so tests can call it directly with a fixed [now].
  static List<AlertItem> build(TrackerViewModel vm, String symbol, DateTime now) {

    final alerts = <AlertItem>[];
    final settings = vm.settings;

    // Daily budget: warns at 80%, then again when exceeded. The ID includes
    // the date, so tomorrow's alert is new even if today's was dismissed.
    final dailyBudget = settings.dailyBudget;
    if (settings.budgetWarningsEnabled && dailyBudget != null && dailyBudget > 0) {
      final todayStart = DateTime(now.year, now.month, now.day);
      final spentToday = vm.spentTotal(todayStart, now);
      final pct = spentToday / dailyBudget;
      if (pct >= 1) {
        alerts.add(AlertItem(
          id: 'daily_budget_over_${todayStart.toIso8601String()}',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.danger,
          iconBg: AppColors.danger.withValues(alpha: 0.15),
          title: 'Daily budget exceeded',
          description:
              "You've spent ${MoneyFormat.money(spentToday, symbol: symbol)} today, over your ${MoneyFormat.money(dailyBudget, symbol: symbol)} daily budget.",
          when: now,
        ));
      } else if (pct >= 0.8) {
        alerts.add(AlertItem(
          id: 'daily_budget_80_${todayStart.toIso8601String()}',
          icon: Icons.timer_outlined,
          iconColor: AppColors.warning,
          iconBg: AppColors.warning.withValues(alpha: 0.15),
          title: 'Daily budget crossed 80%',
          description:
              "You've spent ${MoneyFormat.money(spentToday, symbol: symbol)} of your ${MoneyFormat.money(dailyBudget, symbol: symbol)} daily budget.",
          when: now,
        ));
      }
    }

    // Category budgets: same 80% / exceeded thresholds over each budget's
    // own period. Both share one ID per budget, so dismissing the 80%
    // warning also hides the "exceeded" one for that budget.
    for (final budget in settings.budgetWarningsEnabled ? vm.budgets : const <Budget>[]) {
      final cat = vm.categoryById(budget.categoryId);
      final (periodStart, periodEnd) = budget.periodFor(now);
      final spent = vm.spentByCategory(periodStart, periodEnd, budget.categoryId);
      final pct = budget.amount > 0 ? spent / budget.amount : 0.0;
      if (pct < 0.8) continue;
      final catName = cat?.name ?? 'category';
      final over = spent > budget.amount;
      if (over) {
        alerts.add(AlertItem(
          id: 'budget_${budget.id}',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.danger,
          iconBg: AppColors.danger.withValues(alpha: 0.15),
          title: 'Budget exceeded \u2014 $catName',
          description:
              '$catName is ${MoneyFormat.money(spent - budget.amount, symbol: symbol)} over its ${MoneyFormat.money(budget.amount, symbol: symbol)} budget ${budget.periodLabel}.',
          when: now.subtract(const Duration(hours: 2)),
        ));
      } else {
        alerts.add(AlertItem(
          id: 'budget_${budget.id}',
          icon: Icons.timer_outlined,
          iconColor: AppColors.warning,
          iconBg: AppColors.warning.withValues(alpha: 0.15),
          title: 'Budget crossed 80% \u2014 $catName',
          description:
              "You've used ${MoneyFormat.money(spent, symbol: symbol)} of your ${MoneyFormat.money(budget.amount, symbol: symbol)} $catName budget.",
          when: now.subtract(const Duration(hours: 2)),
        ));
      }
    }

    // Bills due within their reminder window, or overdue. A window of 0 (or
    // less) is treated as the default of 3 days.
    for (final bill in settings.billRemindersEnabled ? vm.bills : const <Bill>[]) {
      final threshold = bill.reminderDaysBefore > 0 ? bill.reminderDaysBefore : 3;
      if (!bill.isDueWithin(threshold)) continue;
      final days = bill.daysUntilDue;
      final over = bill.isOverdue;
      alerts.add(AlertItem(
        id: 'bill_${bill.id}',
        icon: Icons.water_drop_outlined,
        iconColor: const Color(0xFF42A5F5),
        iconBg: const Color(0xFF42A5F5).withValues(alpha: 0.15),
        title: over ? 'Bill overdue \u2014 ${bill.name}' : 'Bill due ${_dueLabel(days)} \u2014 ${bill.name}',
        description:
            '${bill.name} bill of ${MoneyFormat.money(bill.amount, symbol: symbol)} ${over ? 'is overdue.' : 'is due ${_dueLabel(days)}.'}',
        when: now.subtract(Duration(days: days.abs(), hours: 1)),
      ));
    }

    if (settings.unusualSpendingEnabled) alerts.addAll(_unusualSpending(vm, symbol, now));

    // A rolling 7-day summary (today plus the 6 days before), not a
    // calendar week.
    if (settings.weeklySummaryEnabled) {
      final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final spent = vm.spentTotal(weekStart, now);
      final income = vm.incomeTotal(weekStart, now);
      alerts.add(AlertItem(
        id: 'weekly_summary_${weekStart.toIso8601String()}',
        icon: Icons.insights_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.primary.withValues(alpha: 0.15),
        title: 'Your last 7 days',
        description:
            'Spent ${MoneyFormat.money(spent, symbol: symbol)} and received ${MoneyFormat.money(income, symbol: symbol)}.',
        when: now.subtract(const Duration(hours: 3)),
      ));
    }

    alerts.sort((a, b) => b.when.compareTo(a.when));
    return alerts;
  }

  /// Flags expenses from the last 7 days that are at least 3x the usual
  /// amount for their category (based on the 90 days before, needing at
  /// least 5 earlier entries so one-off categories don't trigger it).
  static List<AlertItem> _unusualSpending(TrackerViewModel vm, String symbol, DateTime now) {
    final recentFrom = now.subtract(const Duration(days: 7));
    final historyFrom = recentFrom.subtract(const Duration(days: 90));
    final history = <String, List<double>>{};
    for (final t in vm.transactions) {
      if (t.type != TxType.expense || t.categoryId.isEmpty) continue;
      if (t.dateTime.isBefore(historyFrom) || !t.dateTime.isBefore(recentFrom)) continue;
      history.putIfAbsent(t.categoryId, () => []).add(t.amount);
    }
    final items = <AlertItem>[];
    for (final t in vm.transactions) {
      if (t.type != TxType.expense || t.dateTime.isBefore(recentFrom)) continue;
      final past = history[t.categoryId];
      if (past == null || past.length < 5) continue;
      final avg = past.reduce((a, b) => a + b) / past.length;
      if (avg <= 0 || t.amount < avg * 3) continue;
      final catName = vm.categoryById(t.categoryId)?.name ?? 'this category';
      items.add(AlertItem(
        id: 'unusual_${t.id}',
        icon: Icons.trending_up,
        iconColor: AppColors.warning,
        iconBg: AppColors.warning.withValues(alpha: 0.15),
        title: 'Unusual spending — $catName',
        description:
            '${MoneyFormat.money(t.amount, symbol: symbol)} is about ${(t.amount / avg).toStringAsFixed(0)}x your usual ${MoneyFormat.money(avg, symbol: symbol)} for $catName.',
        when: t.dateTime,
      ));
    }
    return items;
  }

  /// "today", "tomorrow" or "in N days".
  static String _dueLabel(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}
