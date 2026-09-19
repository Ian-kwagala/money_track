import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';

enum DayFilter { all, today, yesterday }

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DayFilter _filter = DayFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;

    var all = vm.transactions;
    if (_filter == DayFilter.today) {
      all = all.where((t) => MoneyFormat.isSameDay(t.dateTime, DateTime.now())).toList();
    } else if (_filter == DayFilter.yesterday) {
      final y = DateTime.now().subtract(const Duration(days: 1));
      all = all.where((t) => MoneyFormat.isSameDay(t.dateTime, y)).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      all = all.where((t) {
        final cat = vm.categoryById(t.categoryId);
        return t.note.toLowerCase().contains(query) ||
            (cat?.name.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    final grouped = <DateTime, List<TxRecord>>{};
    for (final t in all) {
      final day = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      grouped.putIfAbsent(day, () => []).add(t);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'All Expenses',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search expenses...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SegmentedButton<DayFilter>(
              segments: const [
                ButtonSegment(value: DayFilter.all, label: Text('All')),
                ButtonSegment(value: DayFilter.today, label: Text('Today')),
                ButtonSegment(
                    value: DayFilter.yesterday, label: Text('Yesterday')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          Expanded(
            child: days.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses yet',
                    message:
                        'Your transactions will appear here. Tap + on the home screen to add your first one.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
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
        Text(
          MoneyFormat.money(total, symbol: symbol),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}