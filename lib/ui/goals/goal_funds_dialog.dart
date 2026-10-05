import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/savings_goal.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../format/money_input.dart';

/// Add money to, or withdraw money from, a savings goal. The user picks the
/// wallet the money comes from (or goes back to), so wallet balances stay in
/// step with the goal; "Not from a wallet" just adjusts the goal (e.g. money
/// already saved elsewhere). Shared by the goals list and goal details.
Future<void> showGoalFundsDialog(BuildContext context, SavingsGoal goal, {required bool adding}) async {
  final vm = context.read<TrackerViewModel>();
  final symbol = vm.settings.currencySymbol;
  final ctrl = TextEditingController();
  String? walletId = vm.wallets.isEmpty ? null : vm.wallets.first.id;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(adding ? 'Add to ${goal.name}' : 'Withdraw from ${goal.name}'),
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
                hintText: adding ? 'e.g. 50,000' : 'Up to ${MoneyInput.text(goal.currentAmount, emptyIfZero: false)}',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: walletId,
              decoration: InputDecoration(labelText: adding ? 'Take it from' : 'Put it back into'),
              items: [
                for (final w in vm.wallets)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text('${w.name} (${MoneyFormat.compactSigned(vm.walletBalance(w.id), symbol: symbol)})'),
                  ),
                const DropdownMenuItem(value: null, child: Text('Not from a wallet')),
              ],
              onChanged: (v) => setState(() => walletId = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(adding ? 'Add' : 'Withdraw')),
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
  if (!adding && amount > goal.currentAmount) amount = goal.currentAmount;
  if (amount <= 0) return;

  goal.currentAmount += adding ? amount : -amount;
  await vm.updateSavingsGoal(goal);
  if (walletId != null) {
    await vm.recordLinkedMovement(
      linkId: 'goal:${goal.id}',
      walletId: walletId!,
      amount: amount,
      intoWallet: !adding,
      note: adding ? 'Saved to ${goal.name}' : 'Withdrawn from ${goal.name}',
    );
  }
  messenger.showSnackBar(SnackBar(
    content: Text(adding
        ? 'Added ${MoneyFormat.money(amount, symbol: symbol)} to ${goal.name}'
        : 'Withdrew ${MoneyFormat.money(amount, symbol: symbol)} from ${goal.name}'),
  ));
}
