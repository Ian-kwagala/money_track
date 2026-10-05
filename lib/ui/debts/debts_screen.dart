import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../format/money_input.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Money the user owes and money owed to them. Borrowing, lending and
/// repayments can optionally be recorded against a wallet so balances match.
class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final open = vm.debts.where((d) => !d.isSettled).toList();
    final iOwe = open.where((d) => d.direction == DebtDirection.owedByMe).fold<double>(0, (s, d) => s + d.amount);
    final owedToMe = open.where((d) => d.direction == DebtDirection.owedToMe).fold<double>(0, (s, d) => s + d.amount);

    // Open debts first (soonest due first, undated last), settled at the bottom.
    final sorted = [...vm.debts]..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        if (a.dueDate == null && b.dueDate == null) return b.createdAt.compareTo(a.createdAt);
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: 'Debts', subtitle: '${open.length} open'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _TotalCard(label: 'You owe', amount: iOwe, symbol: symbol, color: AppColors.danger)),
                      const SizedBox(width: 12),
                      Expanded(child: _TotalCard(label: 'Owed to you', amount: owedToMe, symbol: symbol, color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (vm.debts.isEmpty)
                    Column(
                      children: [
                        const EmptyState(
                          icon: Icons.handshake_outlined,
                          title: 'No debts tracked',
                          message: 'Keep track of money you owe and money people owe you, with due dates and repayments.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _editDebtDialog(context, vm),
                          icon: const Icon(Icons.add),
                          label: const Text('Add debt'),
                        ),
                      ],
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your debts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        TextButton.icon(
                          onPressed: () => _editDebtDialog(context, vm),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add debt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final d in sorted)
                      _DebtCard(
                        debt: d,
                        symbol: symbol,
                        onEdit: () => _editDebtDialog(context, vm, existing: d),
                        onPay: () => _recordPaymentDialog(context, vm, d),
                        onDelete: () => _confirmDelete(context, vm, d),
                      ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDebtDialog(BuildContext context, TrackerViewModel vm, {Debt? existing}) async {
    final isNew = existing == null;
    final personCtrl = TextEditingController(text: existing?.counterparty ?? '');
    final amountCtrl = TextEditingController(text: existing == null ? '' : MoneyInput.text(existing.amount));
    final noteCtrl = TextEditingController(text: existing?.description ?? '');
    var direction = existing?.direction ?? DebtDirection.owedByMe;
    DateTime? dueDate = existing?.dueDate;
    String? walletId; // new debts only: where the borrowed/lent money moved
    final symbol = vm.settings.currencySymbol;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isNew ? 'Add debt' : 'Edit debt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<DebtDirection>(
                  segments: const [
                    ButtonSegment(value: DebtDirection.owedByMe, label: Text('I owe')),
                    ButtonSegment(value: DebtDirection.owedToMe, label: Text('Owed to me')),
                  ],
                  selected: {direction},
                  onSelectionChanged: (s) => setState(() => direction = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: personCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: direction == DebtDirection.owedByMe ? 'Who you owe' : 'Who owes you'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: MoneyInput.keyboardType,
                  inputFormatters: MoneyInput.formatters,
                  decoration: InputDecoration(labelText: isNew ? 'Amount ($symbol)' : 'Amount still owed ($symbol)'),
                ),
                const SizedBox(height: 12),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dueDate == null ? 'No due date' : 'Due ${DateFormat('d MMM yyyy').format(dueDate!)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    if (dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear due date',
                        onPressed: () => setState(() => dueDate = null),
                      ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => dueDate = picked);
                      },
                      child: Text(dueDate == null ? 'Set date' : 'Change'),
                    ),
                  ],
                ),
                if (isNew) ...[
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String?>(
                    initialValue: walletId,
                    decoration: InputDecoration(
                      labelText: direction == DebtDirection.owedByMe ? 'Money received into' : 'Money paid out of',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Don't record in a wallet")),
                      for (final w in vm.wallets) DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) => setState(() => walletId = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final person = personCtrl.text.trim();
    final amount = MoneyInput.parse(amountCtrl.text) ?? 0;
    if (person.isEmpty || amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a name and an amount')));
      return;
    }
    final note = noteCtrl.text.trim();

    if (existing != null) {
      existing
        ..counterparty = person
        ..amount = amount
        ..direction = direction
        ..dueDate = dueDate
        ..description = note.isEmpty ? null : note
        ..isSettled = false;
      await vm.updateDebt(existing);
      messenger.showSnackBar(const SnackBar(content: Text('Debt updated')));
      return;
    }

    final debt = Debt(
      id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
      counterparty: person,
      amount: amount,
      direction: direction,
      dueDate: dueDate,
      description: note.isEmpty ? null : note,
    );
    await vm.addDebt(debt);
    if (walletId != null) {
      final borrowed = direction == DebtDirection.owedByMe;
      await vm.recordLinkedMovement(
        linkId: 'debt:${debt.id}',
        walletId: walletId!,
        amount: amount,
        intoWallet: borrowed,
        note: borrowed ? 'Borrowed from $person' : 'Lent to $person',
      );
    }
    messenger.showSnackBar(const SnackBar(content: Text('Debt saved')));
  }

  Future<void> _recordPaymentDialog(BuildContext context, TrackerViewModel vm, Debt debt) async {
    final symbol = vm.settings.currencySymbol;
    final iOwe = debt.direction == DebtDirection.owedByMe;
    final ctrl = TextEditingController(text: MoneyInput.text(debt.amount));
    String? walletId = vm.wallets.isEmpty ? null : vm.wallets.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(iOwe ? 'Pay back ${debt.counterparty}' : '${debt.counterparty} paid you'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: MoneyInput.keyboardType,
                inputFormatters: MoneyInput.formatters,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount ($symbol)',
                  helperText: 'Still owed: ${MoneyFormat.money(debt.amount, symbol: symbol)}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: walletId,
                decoration: InputDecoration(labelText: iOwe ? 'Paid from' : 'Received into'),
                items: [
                  for (final w in vm.wallets) DropdownMenuItem(value: w.id, child: Text(w.name)),
                  const DropdownMenuItem(value: null, child: Text('Not through a wallet')),
                ],
                onChanged: (v) => setState(() => walletId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    var amount = MoneyInput.parse(ctrl.text) ?? 0;
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (amount > debt.amount) amount = debt.amount;

    debt.amount -= amount;
    if (debt.amount <= 0) {
      debt.amount = 0;
      debt.isSettled = true;
    }
    await vm.updateDebt(debt);
    if (walletId != null) {
      await vm.recordLinkedMovement(
        linkId: 'debt:${debt.id}',
        walletId: walletId!,
        amount: amount,
        intoWallet: !iOwe,
        note: iOwe ? 'Repaid ${debt.counterparty}' : 'Repayment from ${debt.counterparty}',
      );
    }
    messenger.showSnackBar(SnackBar(
      content: Text(debt.isSettled ? 'Debt with ${debt.counterparty} settled' : 'Payment of ${MoneyFormat.money(amount, symbol: symbol)} recorded'),
    ));
  }

  Future<void> _confirmDelete(BuildContext context, TrackerViewModel vm, Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete debt with ${debt.counterparty}?'),
        content: const Text('Wallet records already made for it are kept. This can’t be undone.'),
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
    if (confirmed != true) return;
    await vm.deleteDebt(debt.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debt deleted')));
    }
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final Color color;

  const _TotalCard({required this.label, required this.amount, required this.symbol, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                MoneyFormat.money(amount, symbol: symbol),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: amount > 0 ? color : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final String symbol;
  final VoidCallback onEdit;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  const _DebtCard({required this.debt, required this.symbol, required this.onEdit, required this.onPay, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final iOwe = debt.direction == DebtDirection.owedByMe;
    final accent = iOwe ? AppColors.danger : AppColors.success;
    final now = DateTime.now();
    final overdue = !debt.isSettled && debt.dueDate != null && debt.dueDate!.isBefore(DateTime(now.year, now.month, now.day));

    final String status;
    final Color statusColor;
    if (debt.isSettled) {
      status = 'Settled';
      statusColor = AppColors.success;
    } else if (debt.dueDate == null) {
      status = 'No due date';
      statusColor = AppColors.mutedForeground;
    } else if (overdue) {
      status = 'Overdue since ${DateFormat('d MMM').format(debt.dueDate!)}';
      statusColor = AppColors.danger;
    } else {
      status = 'Due ${DateFormat('d MMM yyyy').format(debt.dueDate!)}';
      statusColor = AppColors.mutedForeground;
    }

    return Opacity(
      opacity: debt.isSettled ? 0.6 : 1,
      child: Card(
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
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(iOwe ? Icons.call_made : Icons.call_received, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(debt.counterparty,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                          Text(MoneyFormat.money(debt.amount, symbol: symbol),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: debt.isSettled ? AppColors.textPrimary : accent)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        iOwe ? 'You owe' : 'Owes you',
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                      if (debt.description != null && debt.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(debt.description!, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                      ],
                      const SizedBox(height: 4),
                      Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (!debt.isSettled)
                            TextButton(
                              onPressed: onPay,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: Text(iOwe ? 'Record repayment' : 'Record payment received',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.mutedForeground),
                            onPressed: onEdit,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Edit debt',
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.mutedForeground),
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete debt',
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
      ),
    );
  }
}
