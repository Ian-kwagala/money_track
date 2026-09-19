import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_shell.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _rangeIndex = 1; // 0=Week, 1=Month, 2=Year

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();

    final monthStart = DateTime(now.year, now.month, 1);
    final spentThisMonth = vm.spentTotal(monthStart, now);
    final incomeThisMonth = vm.incomeTotal(monthStart, now);
    final savedThisMonth = incomeThisMonth - spentThisMonth;
    final avgDaily = spentThisMonth / now.day;

    // Balance trend — net flow per month for last 12 months
    final balanceTrend = <double>[];
    final trendLabels = <String>[];
    for (var i = 11; i >= 0; i--) {
      final dt = DateTime(now.year, now.month - i, 1);
      final mStart = DateTime(dt.year, dt.month, 1);
      final mEnd = DateTime(dt.year, dt.month + 1, 0);
      final inc = vm.incomeTotal(mStart, mEnd);
      final exp = vm.spentTotal(mStart, mEnd);
      balanceTrend.add(inc - exp);
      trendLabels.add(_monthName(dt.month).substring(0, 3));
    }

    // Growth vs last month
    final currentNet = balanceTrend.isNotEmpty ? balanceTrend.last : 0.0;
    final prevNet = balanceTrend.length >= 2 ? balanceTrend[balanceTrend.length - 2] : 0.0;
    final growthPct = prevNet != 0 ? ((currentNet - prevNet) / prevNet.abs() * 100) : 0.0;
    final growthUp = growthPct >= 0;

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
    final maxYIncomeExpense = monthly.isEmpty
        ? 1.0
        : monthly.fold<double>(0, (mx, m) {
            final i = m['income'] as double;
            final e = m['expense'] as double;
            return mx > i && mx > e ? mx : (i > e ? i : e);
          }) * 1.2;

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
                  // Range selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(AppColors.radius2xl),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _rangeIndex = i),
                              borderRadius: BorderRadius.circular(AppColors.radius2xl),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _rangeIndex == i ? AppColors.card : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppColors.radius2xl),
                                  boxShadow: _rangeIndex == i ? AppColors.shadowSoft : null,
                                ),
                                child: Center(
                                  child: Text(
                                    ['Week', 'Month', 'Year'][i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _rangeIndex == i ? AppColors.textPrimary : AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Balance trend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Last 12 months \u00b7 net income - expense',
                              style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 1)),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text(MoneyFormat.compact(v, symbol: symbol), style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)))),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    return i >= 0 && i < trendLabels.length ? Text(trendLabels[i], style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)) : const Text('');
                                  })),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: List.generate(balanceTrend.length, (i) => FlSpot(i.toDouble(), balanceTrend[i])),
                                    isCurved: true,
                                    color: AppColors.primary,
                                    barWidth: 3,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prevNet == 0 && currentNet == 0
                                ? 'No transactions yet'
                                : growthPct.isNaN
                                    ? 'No data from last month'
                                    : '${growthUp ? "\u2191" : "\u2193"} ${growthPct.abs().toStringAsFixed(1)}% since last month',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: prevNet == 0 && currentNet == 0 ? AppColors.mutedForeground : growthUp ? AppColors.success : AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                      maxY: maxYIncomeExpense < 1 ? 1 : maxYIncomeExpense,
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
                                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 1)),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text(MoneyFormat.compact(v, symbol: symbol), style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)))),
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

                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Saved this month', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                                const SizedBox(height: 6),
                                Text(MoneyFormat.money(savedThisMonth, symbol: symbol), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Avg daily spend', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                                const SizedBox(height: 6),
                                Text(MoneyFormat.money(avgDaily.roundToDouble(), symbol: symbol), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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