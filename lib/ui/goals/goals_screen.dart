import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/savings_goal.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../home_shell.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'goal_details_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final totalSaved = vm.savingsGoals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalTarget = vm.savingsGoals.fold<double>(0, (sum, g) => sum + g.targetAmount);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: 'Savings goals', subtitle: '${vm.savingsGoals.length} goals in progress'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total saved card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total saved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                          const SizedBox(height: 6),
                          Text(MoneyFormat.money(totalSaved, symbol: symbol), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          Text('of ${MoneyFormat.money(totalTarget, symbol: symbol)} across all goals', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Goal cards
                  if (vm.savingsGoals.isEmpty)
                    EmptyState(
                      icon: Icons.flag_outlined,
                      title: 'No goals yet',
                      message: 'Create a goal to start saving toward something meaningful \u2014 a laptop, a trip, or anything in between.',
                      action: FilledButton.icon(
                        onPressed: () => _showGoalDialog(context, vm),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create a goal'),
                      ),
                    )
                  else
                    ...vm.savingsGoals.map((g) => _GoalCard(
                          goal: g,
                          symbol: symbol,
                          onAddFunds: () => _showAddFundsDialog(context, vm, g),
                          onDelete: () => _confirmDeleteGoal(context, vm, g),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => GoalDetailsScreen(goal: g)),
                          ),
                        )),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGoalDialog(BuildContext context, TrackerViewModel vm) async {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final currentController = TextEditingController();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create savings goal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Goal name')),
              const SizedBox(height: 12),
              TextField(controller: targetController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target amount')),
              const SizedBox(height: 12),
              TextField(controller: currentController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Current amount')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {
            'name': nameController.text.trim(),
            'target': double.tryParse(targetController.text) ?? 0,
            'current': double.tryParse(currentController.text) ?? 0,
            'deadline': date,
          }), child: const Text('Save')),
        ],
      ),
    );

    if (result == null || (result['name'] as String).isEmpty) return;

    final goal = SavingsGoal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      name: result['name'] as String,
      targetAmount: (result['target'] as double).abs(),
      currentAmount: (result['current'] as double).abs(),
      deadline: result['deadline'] as DateTime,
      color: const Color(0xFF26A69A).toARGB32(),
    );

    await vm.addSavingsGoal(goal);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savings goal saved')));
  }

  Future<void> _confirmDeleteGoal(BuildContext context, TrackerViewModel vm, SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${goal.name}"?'),
        content: const Text('This will remove the savings goal. Wallet balances will not be altered.'),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal deleted')));
    }
  }

  Future<void> _showAddFundsDialog(BuildContext context, TrackerViewModel vm, SavingsGoal goal) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add funds to ${goal.name}'),
        content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true, decoration: const InputDecoration(labelText: 'Amount', hintText: 'e.g. 50000')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () { final v = double.tryParse(ctrl.text.replaceAll(',', '')); Navigator.pop(ctx, v); }, child: const Text('Add')),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    goal.currentAmount += amount;
    await vm.updateSavingsGoal(goal);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${amount.toStringAsFixed(0)} to ${goal.name}')));
  }
}

IconData _iconForGoal(String icon) {
  switch (icon) {
    case 'savings': return Icons.shield_outlined;
    case 'laptop': return Icons.laptop_outlined;
    case 'other_houses': return Icons.location_on_outlined;
    case 'flight': return Icons.flight_outlined;
    default: return Icons.flag_outlined;
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final String symbol;
  final VoidCallback onAddFunds;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _GoalCard({required this.goal, required this.symbol, required this.onAddFunds, required this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;
    final color = Color(goal.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                      Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconForGoal(goal.icon), color: color, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(goal.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${MoneyFormat.money(goal.currentAmount, symbol: symbol)} of ${MoneyFormat.money(goal.targetAmount, symbol: symbol)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Text('${DateFormat('d MMM yyyy').format(goal.deadline)} \u00b7 $daysLeft days left', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAddFunds,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                  side: BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16),
                    const SizedBox(width: 6),
                    const Text('Add funds', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}