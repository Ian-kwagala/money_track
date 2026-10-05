import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import 'category_avatar.dart';

class TransactionTile extends StatelessWidget {
  final TxRecord tx;
  /// Defaults to opening the transaction for editing (where it can also be
  /// deleted), so every list of transactions behaves the same way.
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final isTransfer = tx.type == TxType.transfer;
    final wallet = vm.walletById(tx.walletId);

    String title;
    String subtitle;
    Color avatarColor;
    if (tx.isOneSided) {
      final touched = vm.walletById(tx.oneSidedWalletId);
      title = tx.note.isNotEmpty ? tx.note : (tx.isOneSidedIn ? 'Money in' : 'Money out');
      subtitle = '${touched.name} · ${_when(tx.dateTime)}';
      avatarColor = AppColors.primary;
    } else if (isTransfer) {
      final toWallet = vm.walletById(tx.toWalletId ?? tx.walletId);
      title = '${wallet.name} → ${toWallet.name}';
      subtitle = _when(tx.dateTime);
      avatarColor = wallet.color != 0 ? Color(wallet.color) : AppTheme.accent;
    } else {
      final cat = vm.categoryById(tx.categoryId);
      title = tx.note.isNotEmpty
          ? tx.note
          : (cat?.name ?? (tx.type == TxType.income ? 'Income' : 'Expense'));
      subtitle = '${wallet.name} · ${_when(tx.dateTime)}';
      avatarColor = cat != null
          ? Color(cat.color)
          : (tx.type == TxType.income ? AppColors.income : AppTheme.primary);
    }

    final amountColor = tx.isOneSided
        ? (tx.isOneSidedIn ? AppColors.income : Theme.of(context).colorScheme.onSurface)
        : switch (tx.type) {
            TxType.income => AppColors.income,
            TxType.expense => Theme.of(context).colorScheme.onSurface,
            TxType.transfer => Theme.of(context).colorScheme.onSurfaceVariant,
          };
    final amountSign = tx.isOneSided
        ? (tx.isOneSidedIn ? '+' : '-')
        : switch (tx.type) {
            TxType.income => '+',
            TxType.expense => '-',
            TxType.transfer => '',
          };

    return InkWell(
      onTap: onTap ??
          () => tx.isOneSided
              ? _showOneSidedInfo(context, vm)
              : Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddTransactionScreen(edit: tx)),
                ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            CategoryAvatar(
              icon: isTransfer
                  ? ''
                  : (vm.categoryById(tx.categoryId)?.icon ?? ''),
              color: avatarColor,
              fallback: _linkKind == 'goal'
                  ? Icons.savings_outlined
                  : _linkKind == 'debt'
                      ? Icons.handshake_outlined
                      : (isTransfer ? Icons.swap_horiz : null),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$amountSign${MoneyFormat.money(
                tx.amount,
                symbol: vm.settings.currencySymbol,
              )}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "goal", "debt" or null, from [TxRecord.linkId].
  String? get _linkKind => tx.linkId?.split(':').first;

  /// One-sided records are managed from their goal/debt (editing them here
  /// would get the two out of sync), so explain that instead of opening the
  /// normal editor. Leftovers from a deleted wallet can simply be deleted.
  Future<void> _showOneSidedInfo(BuildContext context, TrackerViewModel vm) async {
    final kind = _linkKind;
    final (message, route, routeLabel) = switch (kind) {
      'goal' => ('Money moved for a savings goal. Add or withdraw it from Goals.', '/goals', 'Open Goals'),
      'debt' => ('Money moved for a debt. Record repayments from Debts.', '/debts', 'Open Debts'),
      _ => ('The remaining side of a transfer with a wallet you deleted.', null, null),
    };
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx.note.isNotEmpty ? tx.note : 'Transfer'),
        content: Text(message),
        actions: [
          if (route == null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (route != null)
            FilledButton(onPressed: () => Navigator.pop(ctx, 'open'), child: Text(routeLabel!)),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'open' && route != null) {
      Navigator.pushNamed(context, route);
    } else if (action == 'delete') {
      await vm.deleteTransaction(tx.id);
    }
  }

  static String _when(DateTime d) => MoneyFormat.isSameDay(d, DateTime.now())
      ? MoneyFormat.time(d)
      : '${MoneyFormat.shortDay(d)}, ${MoneyFormat.time(d)}';
}
