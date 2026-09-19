import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/savings_goal.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

class GoalDetailsScreen extends StatelessWidget {
  final SavingsGoal goal;

  const GoalDetailsScreen({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final color = Color(goal.color);
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;
    final isOverdue = daysLeft < 0;
    final daysText = isOverdue
        ? '${daysLeft.abs()} days overdue'
        : daysLeft == 0
            ? 'Due today'
            : '$daysLeft days remaining';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete goal',
            onPressed: () => _confirmDelete(context, vm),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goal Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppColors.radiusXl),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flag_outlined, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deadline: ${DateFormat('d MMMM yyyy').format(goal.deadline)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOverdue ? AppColors.danger.withValues(alpha: 0.15) : color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        daysText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOverdue ? AppColors.danger : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Progress Section
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Funding progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text(
                            '${goal.progressPercent.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (goal.progressPercent / 100).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'Saved',
                              value: MoneyFormat.money(goal.currentAmount, symbol: symbol),
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                              label: 'Target',
                              value: MoneyFormat.money(goal.targetAmount, symbol: symbol),
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatBox(
                        label: 'Remaining',
                        value: MoneyFormat.money(goal.remainingAmount, symbol: symbol),
                        color: goal.remainingAmount <= 0 ? AppColors.success : AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Add funds action button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showAddFundsDialog(context, vm),
                  icon: const Icon(Icons.add),
                  label: const Text('Add funds to goal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddFundsDialog(BuildContext context, TrackerViewModel vm) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add funds to ${goal.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Amount (${vm.settings.currencySymbol})',
            hintText: 'e.g. 50000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', ''));
              Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0) return;
    goal.currentAmount += amount;
    await vm.updateSavingsGoal(goal);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${MoneyFormat.money(amount, symbol: vm.settings.currencySymbol)} to ${goal.name}')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, TrackerViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${goal.name}"?'),
        content: const Text('This will remove the savings goal. Existing wallet balances will not be altered.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.deleteSavingsGoal(goal.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
