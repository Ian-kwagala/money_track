import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/bill.dart';
import '../../models/frequency.dart';
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

    // Soonest due first; paused bills sink to the bottom.
    final sortedBills = [...vm.bills]..sort((a, b) {
        if (a.isPaused != b.isPaused) return a.isPaused ? 1 : -1;
        return a.nextDueDate.compareTo(b.nextDueDate);
      });

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
                          const Text('Subscriptions included — review to save', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bills list
                  if (vm.bills.isEmpty)
                    Column(
                      children: [
                        const EmptyState(
                          icon: Icons.event_repeat,
                          title: 'No bills yet',
                          message: 'Add your recurring payments and due dates, and MoneyTrack will remind you before each one.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _editBillDialog(context, vm),
                          icon: const Icon(Icons.add),
                          label: const Text('Add bill'),
                        ),
                      ],
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your bills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        TextButton.icon(
                          onPressed: () => _editBillDialog(context, vm),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final bill in sortedBills)
                      _BillCard(
                        bill: bill,
                        symbol: symbol,
                        onEdit: () => _editBillDialog(context, vm, existing: bill),
                        onDelete: () => _confirmDeleteBill(context, vm, bill),
                        onTogglePaid: () => _confirmMarkPaid(context, vm, bill, symbol),
                        onTogglePaused: () {
                          bill.isPaused = !bill.isPaused;
                          vm.updateBill(bill);
                        },
                      ),
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

  Future<void> _confirmMarkPaid(BuildContext context, TrackerViewModel vm, Bill bill, String symbol) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark ${bill.name} as paid?'),
        content: Text(
          'This records ${MoneyFormat.money(bill.amount, symbol: symbol)} as paid today and moves the next due date to '
          '${DateFormat('d MMM yyyy').format(bill.frequency.addCycle(DateTime.now(), customDays: bill.customDays))}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    bill.isPaid = true;
    bill.lastPaidDate = DateTime.now();
    await vm.updateBill(bill);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${bill.name} marked as paid')));
    }
  }

  Future<void> _confirmDeleteBill(BuildContext context, TrackerViewModel vm, Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${bill.name}?'),
        content: const Text('This will remove the bill and its reminders. This can’t be undone.'),
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
      await vm.deleteBill(bill.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted')));
      }
    }
  }

  static const _billFrequencies = [
    Frequency.daily,
    Frequency.weekly,
    Frequency.biweekly,
    Frequency.monthly,
    Frequency.quarterly,
    Frequency.yearly,
    Frequency.custom,
  ];

  Future<void> _editBillDialog(BuildContext context, TrackerViewModel vm, {Bill? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(text: existing == null ? '' : existing.amount.toStringAsFixed(existing.amount % 1 == 0 ? 0 : 2));
    final customDaysCtrl = TextEditingController(text: existing?.customDays?.toString() ?? '30');
    DateTime dueDate = existing?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    Frequency frequency = existing?.frequency ?? Frequency.monthly;
    int reminderDays = existing?.reminderDaysBefore ?? 3;
    String? categoryId = existing?.categoryId;
    String walletId = existing?.walletId.isNotEmpty == true ? existing!.walletId : (vm.wallets.isNotEmpty ? vm.wallets.first.id : '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add bill' : 'Edit bill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Bill name', hintText: 'e.g. Rent, Netflix, Water'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount (${vm.settings.currencySymbol})'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Frequency>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Repeats'),
                  items: [
                    for (final f in _billFrequencies) DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => frequency = v);
                  },
                ),
                if (frequency == Frequency.custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Every how many days?'),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due date'),
                    child: Text(DateFormat('d MMM yyyy').format(dueDate)),
                  ),
                ),
                const SizedBox(height: 12),
                if (vm.wallets.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: walletId.isNotEmpty ? walletId : null,
                    decoration: const InputDecoration(labelText: 'Pay from wallet'),
                    items: [
                      for (final w in vm.wallets) DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => walletId = v);
                    },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None')),
                    for (final c in vm.expenseCategories)
                      DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setDialogState(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: reminderDays,
                  decoration: const InputDecoration(labelText: 'Remind me before'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 day before')),
                    DropdownMenuItem(value: 3, child: Text('3 days before')),
                    DropdownMenuItem(value: 7, child: Text('7 days before')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => reminderDays = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    final bill = Bill(
      id: existing?.id ?? 'bill_${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim(),
      amount: amount,
      dueDate: dueDate,
      walletId: walletId,
      categoryId: categoryId,
      reminderDaysBefore: reminderDays,
      frequency: frequency,
      customDays: frequency == Frequency.custom ? int.tryParse(customDaysCtrl.text) : null,
      isPaid: existing?.isPaid ?? false,
      isPaused: existing?.isPaused ?? false,
      lastPaidDate: existing?.lastPaidDate,
    );

    if (existing == null) {
      await vm.addBill(bill);
    } else {
      await vm.updateBill(bill);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Bill added' : 'Bill saved')));
    }
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  final String symbol;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePaid;
  final VoidCallback onTogglePaused;

  const _BillCard({
    required this.bill,
    required this.symbol,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePaid,
    required this.onTogglePaused,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = bill.isOverdue;
    final daysUntil = bill.daysUntilDue;
    final statusColor = bill.isPaused
        ? AppColors.mutedForeground
        : isOverdue
            ? AppColors.danger
            : daysUntil <= 3
                ? AppColors.warning
                : AppColors.primary;

    String statusLabel;
    if (bill.isPaused) {
      statusLabel = 'Paused';
    } else if (isOverdue) {
      statusLabel = 'Overdue by ${-daysUntil} day${-daysUntil == 1 ? '' : 's'}';
    } else if (daysUntil == 0) {
      statusLabel = 'Due today';
    } else {
      statusLabel = 'Due in $daysUntil day${daysUntil == 1 ? '' : 's'}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(bill.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        Text(MoneyFormat.money(bill.amount, symbol: symbol),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bill.frequency.label} · supposed to pay on ${DateFormat('d MMM').format(bill.nextDueDate)}',
                      style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          bill.isPaused ? Icons.pause_circle_outline : (isOverdue ? Icons.error_outline : Icons.event_outlined),
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: onTogglePaid,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('Mark paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: onTogglePaused,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: AppColors.mutedForeground),
                          child: Text(bill.isPaused ? 'Resume' : 'Pause', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.mutedForeground),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit bill',
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.mutedForeground),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete bill',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
