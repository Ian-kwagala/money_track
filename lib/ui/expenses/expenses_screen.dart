import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';

enum PeriodFilter { all, today, week, month }

extension on PeriodFilter {
  String get label => switch (this) {
        PeriodFilter.all => 'All time',
        PeriodFilter.today => 'Today',
        PeriodFilter.week => 'Last 7 days',
        PeriodFilter.month => 'This month',
      };
}

/// Full, searchable list of every transaction. Tapping one opens it for
/// editing or deleting.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  PeriodFilter _period = PeriodFilter.all;
  TxType? _type; // null = all types
  String _query = '';

  bool _inPeriod(DateTime d, DateTime now) {
    switch (_period) {
      case PeriodFilter.all:
        return true;
      case PeriodFilter.today:
        return MoneyFormat.isSameDay(d, now);
      case PeriodFilter.week:
        return !d.isBefore(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)));
      case PeriodFilter.month:
        return d.year == now.year && d.month == now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();
    final query = _query.trim().toLowerCase().replaceAll(',', '');

    final filtered = vm.transactions.where((t) {
      if (_type != null && t.type != _type) return false;
      if (!_inPeriod(t.dateTime, now)) return false;
      if (query.isEmpty) return true;
      final cat = vm.categoryById(t.categoryId);
      final wallet = vm.walletById(t.walletId);
      return t.note.toLowerCase().contains(query) ||
          (cat?.name.toLowerCase().contains(query) ?? false) ||
          wallet.name.toLowerCase().contains(query) ||
          t.amount.toStringAsFixed(0).contains(query);
    }).toList();

    final spent = filtered.where((t) => t.type == TxType.expense).fold<double>(0, (s, t) => s + t.amount);
    final received = filtered.where((t) => t.type == TxType.income).fold<double>(0, (s, t) => s + t.amount);

    final grouped = <DateTime, List<TxRecord>>{};
    for (final t in filtered) {
      final day = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      grouped.putIfAbsent(day, () => []).add(t);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Transactions',
              subtitle: '${filtered.length} shown · tap one to edit',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search note, category, wallet or amount',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.muted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<TxType?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('All')),
                      ButtonSegment(value: TxType.expense, label: Text('Expenses')),
                      ButtonSegment(value: TxType.income, label: Text('Income')),
                      ButtonSegment(value: TxType.transfer, label: Text('Transfers')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in PeriodFilter.values)
                        ChoiceChip(
                          label: Text(p.label),
                          selected: _period == p,
                          onSelected: (_) => setState(() => _period = p),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spent ${MoneyFormat.money(spent, symbol: symbol)} · Received ${MoneyFormat.money(received, symbol: symbol)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (days.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: vm.transactions.isEmpty ? 'No transactions yet' : 'Nothing matches',
                message: vm.transactions.isEmpty
                    ? 'Tap + on the home screen to add your first one.'
                    : 'Try a different search or filter.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.list(
                children: [
                  for (final day in days) ...[
                    _DayHeader(
                      label: MoneyFormat.fullDay(day),
                      total: grouped[day]!.fold<double>(
                        0,
                        (sum, t) => sum + (t.type == TxType.expense ? t.amount : 0),
                      ),
                      symbol: symbol,
                    ),
                    const SizedBox(height: 6),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: Column(
                          children: [
                            for (final tx in grouped[day]!) TransactionTile(tx: tx),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final double total;
  final String symbol;

  const _DayHeader({
    required this.label,
    required this.total,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const Spacer(),
        if (total > 0)
          Text(
            '-${MoneyFormat.money(total, symbol: symbol)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
      ],
    );
  }
}
