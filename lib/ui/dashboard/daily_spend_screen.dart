import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../home_shell.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

class DailySpendScreen extends StatelessWidget {
  const DailySpendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final totalBudget = vm.budgets.fold<double>(0, (sum, b) => sum + b.amount);
    final dailyTarget = totalBudget > 0 ? (totalBudget / 30) : 20000.0;
    final spentToday = vm.spentTotal(todayStart, now);
    final todayPct = (spentToday / dailyTarget).clamp(0.0, 1.0);
    final color = todayPct >= 1 ? AppColors.danger : todayPct >= 0.8 ? AppColors.warning : AppColors.primary;
    final remaining = (dailyTarget - spentToday).clamp(0.0, dailyTarget);

    // Weekly data
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dailyAmounts = <double>[];
    for (final d in days) {
      final start = DateTime(d.year, d.month, d.day);
      final v = vm.spentTotal(start, start.add(const Duration(days: 1)));
      dailyAmounts.add(v);
    }
    final weekTotal = dailyAmounts.fold<double>(0, (a, b) => a + b);
    final maxDaily = dailyAmounts.fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = (maxDaily > dailyTarget ? maxDaily : dailyTarget) * 1.25;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Daily spend',
              subtitle: DateFormat('EEEE, d MMMM').format(now),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Big ring
                  Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 190,
                              height: 190,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 190,
                                    height: 190,
                                    child: CircularProgressIndicator(
                                      value: todayPct,
                                      strokeWidth: 14,
                                      backgroundColor: AppColors.border,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Spent today', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                      const SizedBox(height: 4),
                                      Text(MoneyFormat.money(spentToday, symbol: symbol), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                      Text('of ${MoneyFormat.money(dailyTarget, symbol: symbol)}', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppColors.radius2xl)),
                              child: Text('${MoneyFormat.money(remaining, symbol: symbol)} left for today',
                                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // This week bar chart
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('This week', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const Spacer(),
                              Text('${MoneyFormat.money(weekTotal, symbol: symbol)} total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Spent (solid) vs daily target (light)', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 150,
                            child: BarChart(
                              BarChartData(
                                maxY: chartMax > 0 ? chartMax : 35000,
                                barGroups: [
                                  for (var i = 0; i < 7; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barsSpace: 3,
                                      barRods: [
                                        BarChartRodData(toY: dailyTarget, color: AppColors.border, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                        BarChartRodData(toY: dailyAmounts[i], color: dailyAmounts[i] > dailyTarget ? AppColors.danger : AppColors.primary, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                      ],
                                    ),
                                ],
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 22,
                                      getTitlesWidget: (v, meta) {
                                        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                        final i = v.toInt();
                                        return SideTitleWidget(meta: meta, space: 6, child: Text(i >= 0 && i < 7 ? names[i] : '', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)));
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Day rows
                  for (var i = 0; i < 7; i++)
                    _DayRow(day: days[i], target: dailyTarget, spent: dailyAmounts[i], symbol: symbol, isToday: i == now.weekday - 1),
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

class _DayRow extends StatelessWidget {
  final DateTime day;
  final double target;
  final double spent;
  final String symbol;
  final bool isToday;

  const _DayRow({required this.day, required this.target, required this.spent, required this.symbol, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final over = spent > target;
    final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 36, child: Text(dayName, style: TextStyle(fontWeight: isToday ? FontWeight.w800 : FontWeight.w600, color: isToday ? AppColors.primary : AppColors.textPrimary, fontSize: 13))),
            Expanded(child: Text('target ${MoneyFormat.money(target, symbol: symbol)}', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground))),
            Text(MoneyFormat.money(spent, symbol: symbol), style: TextStyle(fontWeight: FontWeight.w700, color: over ? AppColors.danger : AppColors.success, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}