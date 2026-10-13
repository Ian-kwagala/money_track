import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/balance_history.dart';
import '../home_shell.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import 'balance_trend_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();

    // Income vs Expense — last 6 months
    final monthly = <Map<String, dynamic>>[];
    for (var i = 5; i >= 0; i--) {
      final dt = DateTime(now.year, now.month - i, 1);
      final mStart = DateTime(dt.year, dt.month, 1);
      final mEnd = DateTime(dt.year, dt.month + 1, 0);
      monthly.add({
        'm': _monthName(dt.month).substring(0, 3),
        'income': vm.incomeTotal(mStart, mEnd),
        'expense': vm.spentTotal(mStart, mEnd),
      });
    }
    final barAxis = niceAxis([0, for (final m in monthly) ...[m['income'] as double, m['expense'] as double]]);

    // Category totals
    final monthStartDt = DateTime(now.year, now.month, 1);
    final categoryTotals = <_CategoryTotal>[];
    for (final cat in vm.expenseCategories) {
      final amount = vm.spentByCategory(monthStartDt, now, cat.id);
      if (amount > 0) {
        categoryTotals.add(_CategoryTotal(cat.name, cat.color, amount, 0));
      }
    }
    categoryTotals.sort((a, b) => b.amount.compareTo(a.amount));
    final total = categoryTotals.fold<double>(0, (sum, e) => sum + e.amount);
    for (var c in categoryTotals) {
      c.pct = total > 0 ? c.amount / total : 0;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Analytics',
              subtitle: '${_monthName(now.month)} ${now.year}',
              back: false,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spend by category
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Spend by category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 36,
                                        startDegreeOffset: -90,
                                        sections: [
                                          for (var i = 0; i < categoryTotals.take(6).length; i++)
                                            PieChartSectionData(
                                              value: categoryTotals[i].amount,
                                              color: Color(categoryTotals[i].color),
                                              radius: 20,
                                              title: '',
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Total', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                                        Text(MoneyFormat.compact(total, symbol: symbol),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < categoryTotals.take(6).length; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          children: [
                                            Container(width: 7, height: 7, decoration: BoxDecoration(color: Color(categoryTotals[i].color), shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(categoryTotals[i].name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                            Text('${(categoryTotals[i].pct * 100).round()}%',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.mutedForeground)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance trend
                  const BalanceTrendCard(),
                  const SizedBox(height: 16),

                  // Income vs Expense
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Income vs expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('${monthly.isNotEmpty ? "Last ${monthly.length} months" : "No data yet"} \u00b7 Income (green) vs expense (red)', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                          const SizedBox(height: 16),
                          monthly.isEmpty
                              ? const SizedBox(
                                  height: 150,
                                  child: Center(
                                    child: Text('No transactions recorded yet', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                  ),
                                )
                              : SizedBox(
                                  height: 150,
                                  child: BarChart(
                                    BarChartData(
                                      minY: 0,
                                      maxY: barAxis.max,
                                      barGroups: [
                                        for (var i = 0; i < monthly.length; i++)
                                          BarChartGroupData(
                                            x: i,
                                            barsSpace: 4,
                                            barRods: [
                                              BarChartRodData(toY: (monthly[i]['income'] as double), color: AppColors.success, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                              BarChartRodData(toY: (monthly[i]['expense'] as double), color: AppColors.danger, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                            ],
                                          ),
                                      ],
                                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: barAxis.interval, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 1)),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, interval: barAxis.interval, getTitlesWidget: (v, _) => Text(MoneyFormat.compact(v, symbol: symbol), style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)))),
                                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                                          final i = v.toInt();
                                          return i >= 0 && i < monthly.length ? Text(monthly[i]['m'] as String, style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)) : const Text('');
                                        })),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m - 1];
}

class _CategoryTotal {
  final String name;
  final int color;
  final double amount;
  double pct;

  _CategoryTotal(this.name, this.color, this.amount, this.pct);
}