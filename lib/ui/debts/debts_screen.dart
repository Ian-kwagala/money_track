import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../widgets/empty_state.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Debt tracker')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDebtDialog(context, vm),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: vm.debts.isEmpty
            ? const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No debts tracked',
                message:
                    'Track money you owe or are owed with the + button, and keep every lending promise in one place.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                itemCount: vm.debts.length,
                itemBuilder: (_, index) {
                  final debt = vm.debts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: debt.direction == DebtDirection.owedToMe
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(
                          debt.direction == DebtDirection.owedToMe ? Icons.call_received : Icons.call_made,
                          color: debt.direction == DebtDirection.owedToMe ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(debt.counterparty),
                      subtitle: Text(
                        debt.dueDate == null
                            ? 'No due date'
                            : 'Due ${DateFormat('MMM d, yyyy').format(debt.dueDate!)}',
                      ),
                      trailing: Text(
                        'KSh ${debt.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onLongPress: () => vm.deleteDebt(debt.id),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showDebtDialog(BuildContext context, TrackerViewModel vm) async {
    final counterpartyController = TextEditingController();
    final amountController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Track debt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: counterpartyController,
              decoration: const InputDecoration(labelText: 'Counterparty'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'counterparty': counterpartyController.text.trim(),
              'amount': double.tryParse(amountController.text) ?? 0,
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || (result['counterparty'] as String).isEmpty) return;

    final debt = Debt(
      id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
      counterparty: result['counterparty'] as String,
      amount: (result['amount'] as double).abs(),
      direction: DebtDirection.owedByMe,
    );

    await vm.addDebt(debt);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt saved')),
      );
    }
  }
}
