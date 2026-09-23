import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_shell.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final Set<String> _dismissedIds = {};

  List<_AlertItem> _buildAlerts(TrackerViewModel vm, String symbol) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final alerts = <_AlertItem>[];

    final dailyBudget = vm.settings.dailyBudget;
    if (dailyBudget != null && dailyBudget > 0) {
      final todayStart = DateTime(now.year, now.month, now.day);
      final spentToday = vm.spentTotal(todayStart, now);
      final pct = spentToday / dailyBudget;
      if (pct >= 1) {
        alerts.add(_AlertItem(
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
        alerts.add(_AlertItem(
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

    for (final budget in vm.budgets) {
      final cat = vm.categoryById(budget.categoryId);
      final spent = vm.spentByCategory(monthStart, monthEnd, budget.categoryId);
      final pct = budget.amount > 0 ? spent / budget.amount : 0.0;
      if (pct < 0.8) continue;
      final catName = cat?.name ?? 'category';
      final over = spent > budget.amount;
      if (over) {
        alerts.add(_AlertItem(
          id: 'budget_${budget.id}',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.danger,
          iconBg: AppColors.danger.withValues(alpha: 0.15),
          title: 'Budget exceeded \u2014 $catName',
          description:
              '$catName is ${MoneyFormat.money(spent - budget.amount, symbol: symbol)} over its ${MoneyFormat.money(budget.amount, symbol: symbol)} budget this month.',
          when: now.subtract(const Duration(hours: 2)),
        ));
      } else {
        alerts.add(_AlertItem(
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

    for (final bill in vm.bills) {
      if (bill.isPaid) continue;
      final days = bill.dueDate.difference(now).inDays;
      final over = days < 0;
      final threshold = bill.reminderDaysBefore > 0 ? bill.reminderDaysBefore : 3;
      if (!over && !bill.dueDate.isBefore(now.add(Duration(days: threshold)))) continue;
      alerts.add(_AlertItem(
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

    alerts.sort((a, b) => b.when.compareTo(a.when));
    return alerts;
  }

  String _dueLabel(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final alerts = _buildAlerts(vm, symbol).where((a) => !_dismissedIds.contains(a.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: 'Alerts', subtitle: '${alerts.length} unread', back: false),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (alerts.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No alerts yet',
                      message: 'Set a budget or add a bill and you\'ll be\nnotified right here when something needs attention.',
                    )
                  else
                    ...alerts.map((a) => _AlertCard(alert: a, onDismiss: () => setState(() => _dismissedIds.add(a.id)))),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertItem {
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;
  final DateTime when;

  const _AlertItem({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.when,
  });
}

class _AlertCard extends StatelessWidget {
  final _AlertItem alert;
  final VoidCallback onDismiss;

  const _AlertCard({required this.alert, required this.onDismiss});

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: alert.iconBg, shape: BoxShape.circle),
                  child: Icon(alert.icon, color: alert.iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(alert.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.description, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, height: 1.4)),
            const SizedBox(height: 6),
            Text(_timeAgo(alert.when), style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                  side: BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.mutedForeground,
                ),
                child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}