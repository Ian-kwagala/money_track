import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/balance_history.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

/// How the total across all wallets moved over the last week, month or
/// year. The y-axis fits the numbers, so growth shows as the line rising.
class BalanceTrendCard extends StatefulWidget {
  /// For tests; defaults to the real time.
  final DateTime Function()? clock;

  const BalanceTrendCard({super.key, this.clock});

  @override
  State<BalanceTrendCard> createState() => _BalanceTrendCardState();
}

class _BalanceTrendCardState extends State<BalanceTrendCard> {
  TrendRange _range = TrendRange.month;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = (widget.clock ?? DateTime.now)();

    // Same total as Home: the wallets, or income minus spending if there are none.
    final wallets = vm.wallets;
    final history = BalanceHistory(
      currentTotal: wallets.isNotEmpty
          ? wallets.fold<double>(0, (sum, w) => sum + w.currentBalance)
          : vm.transactions.fold<double>(0, (sum, t) => sum + t.signedAmount),
      transactions: vm.transactions,
      walletIds: wallets.isNotEmpty ? {for (final w in wallets) w.id} : null,
    );
    final points = balanceTrend(history, _range, now);
    final totals = [for (final p in points) p.total];
    final axis = niceAxis(totals);
    final change = totals.last - totals.first;
    final nothingYet = vm.transactions.isEmpty;
    // Thin out day labels so they don't collide.
    final labelEvery = switch (_range) { TrendRange.week => 1, TrendRange.month => 5, TrendRange.year => 2 };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Balance trend',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                _RangePicker(value: _range, onChanged: (r) => setState(() => _range = r)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Total across your wallets · ${_range.description}',
                style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: axis.min,
                  maxY: axis.max,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: axis.interval,
                    getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: axis.interval,
                        getTitlesWidget: (v, _) => Text(MoneyFormat.compactSigned(v, symbol: symbol),
                            style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= points.length || v != i.toDouble()) return const SizedBox.shrink();
                          final fromEnd = points.length - 1 - i;
                          if (fromEnd % labelEvery != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(points[i].label,
                                style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary,
                      fitInsideHorizontally: true,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${_tooltipDate(points[s.x.round()], _range)}\n',
                            const TextStyle(color: Colors.white70, fontSize: 10),
                            children: [
                              TextSpan(
                                text: MoneyFormat.signed(s.y, symbol: symbol),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].total)],
                      isCurved: true,
                      curveSmoothness: 0.25,
                      preventCurveOverShooting: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, _) => spot.x == points.length - 1,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary.withValues(alpha: 0.22), AppColors.primary.withValues(alpha: 0.02)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nothingYet
                  ? 'No transactions yet'
                  : change == 0
                      ? 'No change over the ${_range.description}'
                      : '${change > 0 ? '↑' : '↓'} ${MoneyFormat.compact(change, symbol: symbol)} over the ${_range.description}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: nothingYet || change == 0
                    ? AppColors.mutedForeground
                    : change > 0
                        ? AppColors.success
                        : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _tooltipDate(TrendPoint p, TrendRange range) {
    // A point stands for the end of its day (or month), so name that day.
    final d = range == TrendRange.year ? p.at : p.at.subtract(const Duration(seconds: 1));
    return range == TrendRange.year ? '${p.label} ${d.year}' : MoneyFormat.shortDay(d);
  }
}

class _RangePicker extends StatelessWidget {
  final TrendRange value;
  final ValueChanged<TrendRange> onChanged;

  const _RangePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppColors.radius2xl)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in TrendRange.values)
            Semantics(
              selected: r == value,
              button: true,
              child: InkWell(
                onTap: () => onChanged(r),
                borderRadius: BorderRadius.circular(AppColors.radius2xl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: r == value ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppColors.radius2xl),
                    boxShadow: r == value ? AppColors.shadowSoft : null,
                  ),
                  child: Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: r == value ? AppColors.textPrimary : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
