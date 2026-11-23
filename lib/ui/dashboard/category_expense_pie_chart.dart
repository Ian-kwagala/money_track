import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../format/money_format.dart';
import '../theme/app_theme.dart';

/// One slice in the dashboard's expense-by-category pie chart.
class CategoryExpenseSlice {
  final String name;
  final double amount;
  final Color color;

  const CategoryExpenseSlice({
    required this.name,
    required this.amount,
    required this.color,
  });
}

/// Interactive pie chart card showing how this month's expenses are split
/// across categories.
///
/// Uses `fl_chart`'s [PieChart]. When there are more than six categories with
/// spending, the smallest ones are grouped into an "Other" slice so the chart
/// remains easy to read while still representing 100% of monthly expenses.
class CategoryExpensePieChart extends StatefulWidget {
  final List<CategoryExpenseSlice> slices;
  final String symbol;
  final VoidCallback? onAnalyticsTap;

  const CategoryExpensePieChart({
    super.key,
    required this.slices,
    required this.symbol,
    this.onAnalyticsTap,
  });

  /// Builds sorted slices from raw category entries, grouping anything past the
  /// top 6 into an "Other" slice so the pie chart never gets overcrowded.
  static List<CategoryExpenseSlice> groupOverflow(
    List<CategoryExpenseSlice> raw, {
    int maxSlices = 6,
  }) {
    final sorted = raw.where((s) => s.amount > 0).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (sorted.length <= maxSlices) return sorted;

    final head = sorted.take(maxSlices).toList();
    final otherTotal =
        sorted.skip(maxSlices).fold<double>(0, (sum, s) => sum + s.amount);
    if (otherTotal > 0) {
      head.add(CategoryExpenseSlice(
        name: 'Other',
        amount: otherTotal,
        color: AppColors.mutedForeground,
      ));
    }
    return head;
  }

  @override
  State<CategoryExpensePieChart> createState() => _CategoryExpensePieChartState();
}

class _CategoryExpensePieChartState extends State<CategoryExpensePieChart> {
  // Index of the slice currently highlighted by tapping, or null for total.
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final slices = CategoryExpensePieChart.groupOverflow(widget.slices);
    final total = slices.fold<double>(0, (sum, s) => sum + s.amount);

    // Clear stale selection if the underlying slices shrank.
    final activeIndex =
        (_touchedIndex != null && _touchedIndex! >= 0 && _touchedIndex! < slices.length)
            ? _touchedIndex
            : null;
    final activeSlice = activeIndex != null ? slices[activeIndex] : null;
    final centerPct = activeSlice != null && total > 0
        ? '${((activeSlice.amount / total) * 100).round()}%'
        : null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Expenses by category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (widget.onAnalyticsTap != null)
                  InkWell(
                    onTap: widget.onAnalyticsTap,
                    child: const Text(
                      'Analytics',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (slices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No expenses recorded this month',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 124,
                    height: 124,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 38,
                            startDegreeOffset: -90,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                // Only toggle selection on tap-up so scrolling doesn't flicker.
                                if (event is! FlTapUpEvent) return;
                                final idx =
                                    response?.touchedSection?.touchedSectionIndex;
                                setState(() {
                                  if (idx == null || idx < 0 || idx == _touchedIndex) {
                                    _touchedIndex = null;
                                  } else {
                                    _touchedIndex = idx;
                                  }
                                });
                              },
                            ),
                            sections: [
                              for (var i = 0; i < slices.length; i++)
                                PieChartSectionData(
                                  value: slices[i].amount,
                                  color: slices[i].color,
                                  radius: activeIndex == i ? 24 : 20,
                                  title: '',
                                ),
                            ],
                          ),
                        ),
                        // Center summary shows either the selected slice or total monthly spend.
                        SizedBox(
                          width: 68,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activeSlice?.name ?? 'Total',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                MoneyFormat.compact(
                                  activeSlice?.amount ?? total,
                                  symbol: widget.symbol,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (centerPct != null)
                                Text(
                                  centerPct,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: activeSlice!.color,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < slices.length; i++)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() {
                              _touchedIndex = _touchedIndex == i ? null : i;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: slices[i].color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      slices[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: activeIndex == i
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${total > 0 ? ((slices[i].amount / total) * 100).round() : 0}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    MoneyFormat.compact(
                                      slices[i].amount,
                                      symbol: widget.symbol,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
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
    );
  }
}
