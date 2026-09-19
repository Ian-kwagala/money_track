import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/bill.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../home_shell.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final totalMonthly = vm.bills.fold<double>(0, (sum, b) => sum + b.amount);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: 'Recurring & bills', subtitle: '${vm.bills.length} active items'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total monthly card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total monthly recurring', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                          const SizedBox(height: 6),
                          Text(MoneyFormat.money(totalMonthly, symbol: symbol), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Subscriptions included \u2014 review to save', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bills list
                  if (vm.bills.isEmpty)
                    const EmptyState(
                      icon: Icons.event_repeat,
                      title: 'No bills yet',
                      message: 'Add your recurring payments and due dates with the + button, and MoneyTrack will remind you before each one.',
                    )
                  else
                    ...vm.bills.map((bill) => _BillCard(bill: bill, symbol: symbol, onDelete: () => vm.deleteBill(bill.id))),
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

class _BillCard extends StatelessWidget {
  final Bill bill;
  final String symbol;
  final VoidCallback onDelete;

  const _BillCard({required this.bill, required this.symbol, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = bill.dueDate.isBefore(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(bill.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                      Text(MoneyFormat.money(bill.amount, symbol: symbol), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Last paid ${DateFormat('d MMM yyyy').format(bill.dueDate)}', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 12, color: isOverdue ? AppColors.danger : AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        isOverdue ? 'Overdue' : 'Next due ${DateFormat('d MMM yyyy').format(bill.dueDate)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOverdue ? AppColors.danger : AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}