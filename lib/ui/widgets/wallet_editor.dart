import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wallet.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_input.dart';
import '../theme/app_theme.dart';

/// Add a wallet (when [wallet] is null) or edit/delete an existing one.
/// Shared by every screen that manages wallets so they behave the same.
///
/// When editing, the balance field is what the wallet holds *now*; the
/// opening balance is back-calculated so past transactions still count once.
Future<void> showWalletEditor(BuildContext context, {Wallet? wallet}) async {
  final vm = context.read<TrackerViewModel>();
  final isNew = wallet == null;
  final nameCtrl = TextEditingController(text: wallet?.name ?? '');
  final balanceCtrl = TextEditingController(
    text: isNew ? '' : MoneyInput.text(vm.walletBalance(wallet.id)),
  );
  var type = wallet?.type ?? WalletType.cash;

  InputDecoration deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide.none,
        ),
      );

  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(isNew ? 'Add wallet' : 'Edit wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: deco('Wallet name', hint: 'e.g. Equity Bank'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WalletType>(
                initialValue: type,
                decoration: deco('Type'),
                items: WalletType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() => type = v ?? WalletType.cash),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: MoneyInput.keyboardType,
                inputFormatters: MoneyInput.formatters,
                decoration: deco(
                  isNew ? 'Starting balance (${vm.settings.currencySymbol})' : 'Current balance (${vm.settings.currencySymbol})',
                  hint: '0',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(isNew ? 'Add' : 'Save')),
        ],
      ),
    ),
  );

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  if (action == 'delete' && wallet != null) {
    await _confirmDelete(context, vm, wallet);
    return;
  }
  if (action != 'save') return;

  final name = nameCtrl.text.trim();
  if (name.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Give the wallet a name')));
    return;
  }
  final balance = MoneyInput.parse(balanceCtrl.text) ?? 0;

  if (isNew) {
    await vm.saveWallet(Wallet(
      id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: type,
      color: AppColors.primary.toARGB32(),
      openingBalance: balance,
      currentBalance: balance,
    ));
    messenger.showSnackBar(SnackBar(content: Text('Wallet "$name" added')));
  } else {
    wallet.name = name;
    wallet.type = type;
    await vm.setWalletBalance(wallet, balance);
    messenger.showSnackBar(SnackBar(content: Text('Wallet "$name" updated')));
  }
}

Future<void> _confirmDelete(BuildContext context, TrackerViewModel vm, Wallet wallet) async {
  final messenger = ScaffoldMessenger.of(context);
  if (vm.wallets.length <= 1) {
    messenger.showSnackBar(const SnackBar(content: Text('You need at least one wallet. Add another before deleting this one.')));
    return;
  }
  final count = vm.transactionCountForWallet(wallet.id);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${wallet.name}?'),
      content: Text(count == 0
          ? 'This wallet has no transactions. This can’t be undone.'
          : 'Its $count transaction${count == 1 ? '' : 's'} will be removed too. Transfers with your other wallets are kept so their balances don’t change, and any bills paid from it move to another wallet. This can’t be undone.'),
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
  await vm.removeWallet(wallet.id);
  messenger.showSnackBar(SnackBar(content: Text('Wallet "${wallet.name}" deleted')));
}
