import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import 'category_avatar.dart';

class TransactionTile extends StatelessWidget {
  final TxRecord tx;
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
    if (isTransfer) {
      final toWallet = vm.walletById(tx.toWalletId ?? tx.walletId);
      title = '${wallet.name} → ${toWallet.name}';
      subtitle = MoneyFormat.time(tx.dateTime);
      avatarColor = wallet.color != 0 ? Color(wallet.color) : AppTheme.accent;
    } else {
      final cat = vm.categoryById(tx.categoryId);
      title = tx.note.isNotEmpty
          ? tx.note
          : (cat?.name ?? (tx.type == TxType.income ? 'Income' : 'Expense'));
      subtitle =
          '${wallet.name} - ${MoneyFormat.time(tx.dateTime)}';
      avatarColor = cat != null
          ? Color(cat.color)
          : (tx.type == TxType.income ? AppColors.income : AppTheme.primary);
    }

    final amountColor = switch (tx.type) {
      TxType.income => AppColors.income,
      TxType.expense => Theme.of(context).colorScheme.onSurface,
      TxType.transfer => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    final amountSign = switch (tx.type) {
      TxType.income => '+',
      TxType.expense => '-',
      TxType.transfer => '',
    };

    return InkWell(
      onTap: onTap,
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
              fallback: isTransfer ? Icons.swap_horiz : null,
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
}