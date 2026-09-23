import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/frequency.dart';
import '../../models/income_profile.dart';
import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';

/// Nudges the user, once per expected pay cycle, to confirm they were paid
/// and to check off the bills they've settled since. Runs from an anchor of
/// [User.lastPayDate] (seeded from [User.createdAt] until the first
/// confirmation) advanced by [User.incomeFrequency].
class PaydayCheck {
  static const _promptDateKey = 'paydayPromptDate';

  static Future<void> maybeShow(BuildContext context) async {
    final vm = context.read<TrackerViewModel>();
    final user = vm.currentUser;
    if (user.incomeFrequency == IncomeFrequency.irregular) return;

    final anchor = user.lastPayDate ?? user.createdAt;
    if (anchor == null) return;
    final nextPay = user.incomeFrequency.nextDate(anchor);
    if (nextPay == null || DateTime.now().isBefore(nextPay)) return;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString(_promptDateKey) == todayKey) return;
    await prefs.setString(_promptDateKey, todayKey);

    if (!context.mounted) return;
    final label = user.incomeSource == 'salary' ? 'salary' : 'income';
    final received = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Did you receive your $label?'),
        content: Text(
          'Your ${user.incomeFrequency.label.toLowerCase()} $label looked due on ${DateFormat('d MMM').format(nextPay)}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, received')),
        ],
      ),
    );
    if (received != true || !context.mounted) return;

    await _confirmIncome(context, vm, label);
  }

  static Future<void> _confirmIncome(BuildContext context, TrackerViewModel vm, String label) async {
    if (vm.wallets.isEmpty) return;
    final user = vm.currentUser;
    final amountCtrl = TextEditingController(
      text: user.expectedMonthlyIncome > 0 ? user.expectedMonthlyIncome.toStringAsFixed(0) : '',
    );
    String walletId = vm.wallets.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Log your $label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount (${vm.settings.currencySymbol})'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Wallet'),
                items: [for (final w in vm.wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
                onChanged: (v) {
                  if (v != null) setDialogState(() => walletId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(amountCtrl.text.replaceAll(',', ''));
                if (v == null || v <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Log income'),
            ),
          ],
        ),
      ),
    );

    final now = DateTime.now();
    if (confirmed == true) {
      final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
      if (amount != null && amount > 0) {
        final incomeCats = vm.incomeCategories;
        await vm.addTransaction(TxRecord(
          id: 'payday_${now.millisecondsSinceEpoch}',
          type: TxType.income,
          amount: amount,
          walletId: walletId,
          categoryId: incomeCats.isNotEmpty ? incomeCats.first.id : '',
          note: 'Payday',
          dateTime: now,
          frequency: user.incomeFrequency == IncomeFrequency.irregular ? Frequency.random : Frequency.monthly,
        ));
      }
    }

    // Whether logged or skipped, this cycle has been handled — advance the
    // anchor so the prompt doesn't fire again until the next expected payday.
    user.lastPayDate = now;
    await vm.saveUser(user);

    if (context.mounted) await _showBillsChecklist(context, vm);
  }

  static Future<void> _showBillsChecklist(BuildContext context, TrackerViewModel vm) async {
    final unpaidBills = vm.bills.where((b) => !b.isPaused && !b.isPaid).toList();
    if (unpaidBills.isEmpty) return;

    final checked = {for (final b in unpaidBills) b.id: false};
    final amountCtrls = {for (final b in unpaidBills) b.id: TextEditingController(text: b.amount.toStringAsFixed(b.amount % 1 == 0 ? 0 : 2))};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Which bills have you paid?'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final b in unpaidBills)
                    CheckboxListTile(
                      value: checked[b.id],
                      onChanged: (v) => setDialogState(() => checked[b.id] = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(b.name),
                      subtitle: checked[b.id] == true
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TextField(
                                controller: amountCtrls[b.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Amount paid', isDense: true),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final now = DateTime.now();
    for (final b in unpaidBills) {
      if (checked[b.id] != true) continue;
      final amount = double.tryParse(amountCtrls[b.id]!.text.replaceAll(',', '')) ?? b.amount;
      if (b.walletId.isNotEmpty) {
        await vm.addTransaction(TxRecord(
          id: 'bill_pay_${b.id}_${now.millisecondsSinceEpoch}',
          type: TxType.expense,
          amount: amount,
          walletId: b.walletId,
          categoryId: b.categoryId ?? '',
          note: b.name,
          dateTime: now,
        ));
      }
      b.isPaid = true;
      b.lastPaidDate = now;
      await vm.updateBill(b);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bills updated')));
    }
  }
}
