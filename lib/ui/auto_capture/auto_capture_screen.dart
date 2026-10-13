import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/captured_sms.dart';
import '../../models/transaction.dart';
import '../../services/capture/capture_service.dart';
import '../../services/capture/sms_bridge.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'capture_review_sheet.dart';
import 'check_message_sheet.dart';
import 'turn_on_flow.dart';

class AutoCaptureScreen extends StatelessWidget {
  const AutoCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final capture = context.watch<CaptureService>();
    final pending = capture.pending;
    final handled = capture.recentlyHandled;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () => capture.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Auto-capture',
                subtitle: '${pending.length} to review',
                action: capture.isOn ? const _MoreMenu() : null,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Banner(
                      icon: Icons.lock_outline,
                      color: AppColors.primary,
                      text: 'Read from your MTN, Airtel and bank SMS on this phone. Nothing is saved until you confirm it.',
                    ),
                    const SizedBox(height: 12),
                    if (!capture.isSupported)
                      const _Banner(
                        icon: Icons.info_outline,
                        color: AppColors.info,
                        text: 'Reading SMS only works on Android. Copy a money SMS and tap Check a message to add it.',
                      )
                    else if (!capture.isOn)
                      const _TurnOnCard()
                    else if (capture.needsPermission)
                      _Banner(
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        text: 'SMS permission is off, so new messages aren\'t being read.',
                        actionLabel: 'Allow',
                        onAction: () => capture.access == SmsAccess.blocked
                            ? showAllowSmsSteps(context)
                            : turnOnAutoCapture(context),
                      ),
                    if (pending.length > 1) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _confirmAll(context),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text('Confirm all (${pending.length})'),
                        ),
                      ),
                    ],
                    for (final c in pending) ...[
                      _CaptureCard(capture: c),
                      const SizedBox(height: 12),
                    ],
                    if (pending.isEmpty && (capture.isOn || !capture.isSupported)) ...[
                      const SizedBox(height: 24),
                      const EmptyState(
                        icon: Icons.task_alt,
                        title: 'All caught up',
                        message: 'New MTN, Airtel and bank transactions will appear here for you to confirm.',
                      ),
                    ],
                    if (handled.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Recently handled',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      for (final c in handled) _HandledTile(capture: c),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CheckMessageSheet.show(context, onAdd: capture.addPasted),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.content_paste_search),
        label: const Text('Check a message'),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Actions
// -----------------------------------------------------------------------------

Future<void> _confirm(BuildContext context, Capture c) async {
  final service = context.read<CaptureService>();
  final draft = service.draftFor(c);
  if (!draft.isComplete || service.possibleDuplicate(c, draft) != null) return _review(context, c);
  final mismatch = await service.confirm(c, draft);
  if (context.mounted) await _afterConfirm(context, c, mismatch);
}

Future<void> _review(BuildContext context, Capture c) async {
  final outcome = await CaptureReviewSheet.show(context, c);
  if (outcome == null || !context.mounted) return;
  if (outcome.confirmed) {
    await _afterConfirm(context, c, outcome.mismatch);
  } else {
    _showUndo(context, c, 'Ignored');
  }
}

Future<void> _ignore(BuildContext context, Capture c) async {
  await context.read<CaptureService>().ignore(c);
  if (context.mounted) _showUndo(context, c, 'Ignored');
}

Future<void> _afterConfirm(BuildContext context, Capture c, BalanceMismatch? mismatch) async {
  _showUndo(context, c, 'Saved');
  if (mismatch != null) await _offerBalanceMatch(context, [mismatch]);
}

void _showUndo(BuildContext context, Capture c, String what) {
  final service = context.read<CaptureService>();
  final name = c.message.counterparty;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(name == null ? what : '$what · $name'),
      action: SnackBarAction(label: 'Undo', onPressed: () => service.undo(c)),
    ));
}

Future<void> _confirmAll(BuildContext context) async {
  final result = await context.read<CaptureService>().confirmAll();
  if (!context.mounted) return;
  final skipped = result.skipped == 0 ? '' : ' · ${result.skipped} need a closer look';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirmed ${result.confirmed}$skipped')));
  if (result.mismatches.isNotEmpty) await _offerBalanceMatch(context, result.mismatches);
}

Future<void> _offerBalanceMatch(BuildContext context, List<BalanceMismatch> mismatches) async {
  final vm = context.read<TrackerViewModel>();
  final service = context.read<CaptureService>();
  final symbol = vm.settings.currencySymbol;
  final lines = [
    for (final m in mismatches)
      '${vm.walletById(m.walletId).name}: your SMS says ${captureMoney(m.smsBalance, symbol)}, '
          'MoneyTrack shows ${captureMoney(m.appBalance, symbol)}.',
  ];
  final update = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(mismatches.length == 1 ? 'Update wallet balance?' : 'Update wallet balances?'),
      content: Text('${lines.join('\n\n')}\n\nUpdating keeps your transactions and makes the balance match the SMS.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
      ],
    ),
  );
  if (update != true) return;
  for (final m in mismatches) {
    await service.matchBalance(m);
  }
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------

class _CaptureCard extends StatelessWidget {
  final Capture capture;

  const _CaptureCard({required this.capture});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final service = context.read<CaptureService>();
    final m = capture.message;
    final d = service.draftFor(capture);
    final symbol = vm.settings.currencySymbol;
    final duplicate = service.possibleDuplicate(capture, d);
    String walletName(String? id) => id == null ? 'Choose wallet' : vm.walletById(id).name;
    final category = d.categoryId == null ? null : vm.categoryById(d.categoryId!);
    final now = DateTime.now();
    final when = MoneyFormat.isSameDay(capture.when, now)
        ? MoneyFormat.timeShort(capture.when)
        : '${MoneyFormat.shortDay(capture.when)} · ${MoneyFormat.timeShort(capture.when)}';
    final source = capture.record.sender.isEmpty ? 'Pasted message' : '${m.provider.label} SMS';
    final providerWallet = m.kind.isMoneyIn && d.type == TxType.transfer ? d.toWalletId : d.walletId;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: () => _review(context, capture),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${m.kind.label} · ${captureMoney(m.amount, symbol)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: m.kind.isMoneyIn ? AppColors.income : AppColors.textPrimary)),
                  ),
                  Text(when, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(m.counterparty ?? m.provider.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text('$source · ${walletName(providerWallet)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (d.type == TxType.transfer)
                    _Chip(
                      icon: Icons.swap_horiz,
                      label: '${walletName(d.walletId)} → ${walletName(d.toWalletId)}',
                      color: AppColors.info,
                    )
                  else if (category != null)
                    _Chip(
                      icon: category.iconData,
                      label: category.name,
                      color: Color(category.color),
                      onTap: () => _review(context, capture),
                    )
                  else
                    _Chip(
                      icon: Icons.category_outlined,
                      label: 'Choose category',
                      color: AppColors.warning,
                      onTap: () => _review(context, capture),
                    ),
                  if (d.fee > 0)
                    _Chip(icon: Icons.receipt_long, label: '+ fee ${captureMoney(d.fee, symbol)}', color: AppColors.mutedForeground),
                  if (m.pending) const _Chip(icon: Icons.schedule, label: 'Pending', color: AppColors.mutedForeground),
                  if (duplicate != null)
                    const _Chip(icon: Icons.content_copy_outlined, label: 'Already recorded?', color: AppColors.warning),
                ],
              ),
              const SizedBox(height: 10),
              // Explicit sizes: the app theme gives filled buttons an
              // unlimited minimum width, which a Row can't lay out.
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirm(context, capture),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _review(context, capture),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => _ignore(context, capture),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: AppColors.mutedForeground),
                    child: const Text('Ignore'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _Chip({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppColors.radiusSm), child: chip);
  }
}

class _HandledTile extends StatelessWidget {
  final Capture capture;

  const _HandledTile({required this.capture});

  @override
  Widget build(BuildContext context) {
    final symbol = context.watch<TrackerViewModel>().settings.currencySymbol;
    final m = capture.message;
    final confirmed = capture.record.status == CaptureStatus.confirmed;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(confirmed ? Icons.check_circle_outline : Icons.remove_circle_outline,
          color: confirmed ? AppColors.success : AppColors.mutedForeground),
      title: Text('${m.kind.label} · ${captureMoney(m.amount, symbol)}${m.counterparty == null ? '' : ' · ${m.counterparty}'}',
          overflow: TextOverflow.ellipsis),
      subtitle: Text(confirmed ? 'Confirmed' : 'Ignored'),
      trailing: TextButton(
        onPressed: () => context.read<CaptureService>().undo(capture),
        child: const Text('Undo'),
      ),
    );
  }
}

class _TurnOnCard extends StatelessWidget {
  const _TurnOnCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sms_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Fill in transactions from SMS',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn on auto-capture and MoneyTrack lists every MTN, Airtel and bank transaction from your SMS — '
            'including the last 30 days — ready for you to confirm.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => turnOnAutoCapture(context), child: const Text('Turn on')),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    final capture = context.read<CaptureService>();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
      onSelected: (choice) async {
        final messenger = ScaffoldMessenger.of(context);
        if (choice == 'rescan') {
          final n = await capture.refresh(rescan: true);
          messenger.showSnackBar(SnackBar(content: Text(n == 0 ? 'No new transactions found' : 'Found $n new')));
        } else if (choice == 'off') {
          await capture.turnOff();
          messenger.showSnackBar(const SnackBar(content: Text('Auto-capture is off')));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rescan', child: Text('Scan last 30 days again')),
        PopupMenuItem(value: 'off', child: Text('Turn off auto-capture')),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Banner({required this.icon, required this.color, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
