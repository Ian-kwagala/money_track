import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/budget.dart';
import '../../models/frequency.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../home_shell.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  // null = "All" tab.
  Frequency? _filter;

  static const _tabs = <(String, Frequency?)>[
    ('All', null),
    ('Daily', Frequency.daily),
    ('Weekly', Frequency.weekly),
    ('Monthly', Frequency.monthly),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final spentMonth = vm.spentTotal(monthStart, now);
    final totalBudget = vm.budgets.fold<double>(0, (sum, b) => sum + b.amount);
    final overallPct = totalBudget > 0 ? spentMonth / totalBudget : 0.0;
    final remaining = (totalBudget - spentMonth).clamp(0.0, totalBudget);
    final visibleBudgets = _filter == null ? vm.budgets : vm.budgets.where((b) => b.frequency == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Budgets',
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
                  // Overall budget card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Spent of budget', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: MoneyFormat.money(spentMonth, symbol: symbol), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                TextSpan(text: ' / ${MoneyFormat.money(totalBudget, symbol: symbol)}', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: overallPct.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                overallPct >= 1 ? AppColors.danger : overallPct >= 0.8 ? AppColors.warning : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('${MoneyFormat.money(remaining, symbol: symbol)} still available',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category budgets header & empty state
                  if (vm.budgets.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.mutedForeground.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('No budgets yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            const Text(
                              'Set monthly spending limits for your categories to stay on track.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _addBudgetDialog(context, vm),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Budget'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Category budgets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        TextButton.icon(
                          onPressed: () => _addBudgetDialog(context, vm),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add budget', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final tab in _tabs) ...[
                          _FrequencyTab(
                            label: tab.$1,
                            selected: _filter == tab.$2,
                            onTap: () => setState(() => _filter = tab.$2),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (visibleBudgets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No ${_tabs.firstWhere((t) => t.$2 == _filter).$1.toLowerCase()} budgets yet',
                              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        ),
                      ),
                    ...visibleBudgets.map((b) {
                      final cat = vm.categoryById(b.categoryId);
                      if (cat == null) return const SizedBox.shrink();
                      final (periodStart, periodEnd) = b.periodFor(now);
                      final spent = vm.spentByCategory(periodStart, periodEnd, b.categoryId);
                      return _BudgetTile(
                        category: cat,
                        budget: b,
                        spent: spent,
                        symbol: symbol,
                        onEdit: () => _editBudgetDialog(context, vm, category: cat, existing: b),
                        onDelete: () => _confirmDeleteBudget(context, vm, b, cat.name),
                      );
                    }),
                  ],
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

  Future<void> _addBudgetDialog(BuildContext context, TrackerViewModel vm) async {
    final budgetedCategoryIds = vm.budgets.map((b) => b.categoryId).toSet();
    final availableCategories = vm.expenseCategories
        .where((c) => !budgetedCategoryIds.contains(c.id))
        .toList();

    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All expense categories already have a budget.')),
      );
      return;
    }

    Category selectedCat = availableCategories.first;
    Frequency frequency = Frequency.monthly;
    final controller = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Category Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Category>(
                initialValue: selectedCat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in availableCategories)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(c.iconData, color: Color(c.color), size: 18),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedCat = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Frequency>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Resets'),
                items: const [
                  DropdownMenuItem(value: Frequency.daily, child: Text('Daily')),
                  DropdownMenuItem(value: Frequency.weekly, child: Text('Weekly')),
                  DropdownMenuItem(value: Frequency.monthly, child: Text('Monthly')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => frequency = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${frequency.label} limit (${vm.settings.currencySymbol})',
                  hintText: 'e.g. 200000',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text.replaceAll(',', ''));
                if (v == null || v <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final v = double.tryParse(controller.text.replaceAll(',', ''));
      if (v != null && v > 0) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, 1);
        final budget = Budget(
          id: 'budget_${selectedCat.id}_${start.millisecondsSinceEpoch}',
          categoryId: selectedCat.id,
          amount: v,
          periodStart: start,
          frequency: frequency,
        );
        await vm.upsertBudget(budget);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Budget created for ${selectedCat.name}')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteBudget(BuildContext context, TrackerViewModel vm, Budget budget, String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete budget for $categoryName?'),
        content: const Text('This will remove the monthly budget limit for this category. Recorded transactions will not be deleted.'),
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
      await vm.deleteBudget(budget.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget deleted')));
      }
    }
  }

  Future<void> _editBudgetDialog(BuildContext context, TrackerViewModel vm, {required Category category, Budget? existing}) async {
    final controller = TextEditingController(text: existing?.amount.toString() ?? '');
    Frequency frequency = existing?.frequency ?? Frequency.monthly;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Budget for ${category.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Frequency>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Resets'),
                items: const [
                  DropdownMenuItem(value: Frequency.daily, child: Text('Daily')),
                  DropdownMenuItem(value: Frequency.weekly, child: Text('Weekly')),
                  DropdownMenuItem(value: Frequency.monthly, child: Text('Monthly')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => frequency = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${frequency.label} limit')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () { final v = double.tryParse(controller.text.replaceAll(',', '')); Navigator.pop(ctx, v); }, child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == null || result <= 0) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final budget = Budget(id: existing?.id ?? 'budget_${category.id}_${start.millisecondsSinceEpoch}', categoryId: category.id, amount: result, periodStart: start, frequency: frequency);
    await vm.upsertBudget(budget);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget saved')));
  }
}

class _BudgetTile extends StatelessWidget {
  final Category category;
  final Budget budget;
  final double spent;
  final String symbol;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _BudgetTile({
    required this.category,
    required this.budget,
    required this.spent,
    required this.symbol,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct = budget.amount > 0 ? spent / budget.amount : 0.0;
    final remaining = (budget.amount - spent).clamp(0.0, budget.amount);
    final overBudget = spent > budget.amount;
    final pctLabel = '${(pct * 100).round()}%';
    final color = pct >= 1 ? AppColors.danger : pct >= 0.8 ? AppColors.warning : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(category.color).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.iconData, color: Color(category.color), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${MoneyFormat.money(spent, symbol: symbol)} of ${MoneyFormat.money(budget.amount, symbol: symbol)} · ${budget.frequency.label.toLowerCase()}',
                            style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  Text(pctLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.mutedForeground),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit limit',
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.mutedForeground),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete budget',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), minHeight: 8, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation<Color>(color)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  overBudget ? '${MoneyFormat.money(spent - budget.amount, symbol: symbol)} over budget' : '${MoneyFormat.money(remaining, symbol: symbol)} remaining',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: overBudget ? AppColors.danger : Color(category.color)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _FrequencyTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(AppColors.radius2xl),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
