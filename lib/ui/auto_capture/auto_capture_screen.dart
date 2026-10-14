import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/captured_sms.dart';
import '../../models/transaction.dart';
import '../../services/capture/capture_service.dart';
import '../../services/capture/capture_suggestions.dart';
import '../../services/capture/sms_bridge.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/action_button.dart';
import '../widgets/empty_state.dart';
import 'capture_review_sheet.dart';
import 'check_message_sheet.dart';
import 'turn_on_flow.dart';

/// The review list for SMS auto-capture: money messages waiting to be
/// confirmed, edited or ignored, plus recently handled ones (with Undo).
///
/// From top to bottom: a privacy note, a status area (unsupported / turn
/// on / permission missing), "Confirm all", the waiting cards, and the
/// recently handled list. Pull down to re-check for new messages. The
/// floating button pastes a message by hand.
///
/// All the work happens in CaptureService; this file is UI and the confirm
/// flow ([_confirm] and friends below).
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
                    _CaptureList(
                      pending: pending,
                      itemBuilder: (c) => _CaptureCard(
                        capture: c,
                        onConfirm: () => _confirm(context, c),
                        onEdit: () => _review(context, c),
                        onIgnore: () => _ignore(context, c),
                      ),
                    ),
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

/// The card's Confirm. Saves straight away when there's nothing to ask (the
/// button shows its spinner and check). Otherwise it asks first, and the
/// button returns to normal rather than spinning behind a question.
Future<bool> _confirm(BuildContext context, Capture c) async {
  final service = context.read<CaptureService>();
  final draft = service.draftFor(c);
  if (draft.isComplete && service.possibleDuplicate(c, draft) == null) {
    await _save(context, c, draft);
    return true;
  }
  _askThenConfirm(context, c, draft);
  return false;
}

/// Asks only for what's missing (a category is one tap in a picker; anything
/// else opens the full editor) and whether a likely duplicate is one, then saves.
Future<void> _askThenConfirm(BuildContext context, Capture c, CaptureDraft draft) async {
  final service = context.read<CaptureService>();
  final onlyCategoryMissing = draft.missing == 'Pick a category';
  if (draft.missing != null && !onlyCategoryMissing) return _review(context, c);
  if (onlyCategoryMissing) {
    final picked = await _CategoryPicker.show(context, c, draft.type);
    if (picked == null || !context.mounted) return;
    if (picked == _CategoryPicker.moreOptions) return _review(context, c);
    draft.categoryId = picked;
  }
  final duplicate = service.possibleDuplicate(c, draft);
  if (duplicate != null) {
    final save = await _askIfDuplicate(context, duplicate);
    if (save == null || !context.mounted) return;
    if (!save) return _ignore(context, c);
  }
  await _save(context, c, draft);
}

/// Confirms [c] with [draft] and follows up (Undo snackbar, balance check).
Future<void> _save(BuildContext context, Capture c, CaptureDraft draft) async {
  final mismatch = await context.read<CaptureService>().confirm(c, draft);
  // Not awaited: the snackbar and any balance question follow the card's exit.
  if (context.mounted) _afterConfirm(context, c, mismatch);
}

/// True to save anyway, false to ignore the SMS, null to decide later.
Future<bool?> _askIfDuplicate(BuildContext context, TxRecord existing) {
  final symbol = context.read<TrackerViewModel>().settings.currencySymbol;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Already recorded?'),
      content: Text(
        'You already have a ${captureMoney(existing.amount, symbol)} ${existing.type.name} on '
        '${MoneyFormat.shortDay(existing.dateTime)}${existing.note.isEmpty ? '' : ' ("${existing.note}")'}. '
        'If this SMS is the same transaction, ignore it so it isn\'t counted twice.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save anyway')),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ignore SMS')),
      ],
    ),
  );
}

/// Opens the full editor for [c] and reacts to how it was closed.
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

/// After a confirm: offer Undo, then, if the SMS balance disagrees with the
/// wallet, offer to update the wallet.
Future<void> _afterConfirm(BuildContext context, Capture c, BalanceMismatch? mismatch) async {
  _showUndo(context, c, 'Saved');
  if (mismatch == null) return;
  // Let the card's "Saved" check and exit play before asking.
  await Future<void>.delayed(const Duration(milliseconds: 700));
  if (context.mounted) await _offerBalanceMatch(context, [mismatch]);
}

/// "Saved · John" / "Ignored · John" snackbar whose Undo puts the message
/// back in the list (and removes any transactions it created).
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

/// Confirms every card that needs no questions (see
/// CaptureService.confirmAll) and reports how many were left for review.
Future<void> _confirmAll(BuildContext context) async {
  final result = await context.read<CaptureService>().confirmAll();
  if (!context.mounted) return;
  final skipped = result.skipped == 0 ? '' : ' · ${result.skipped} need a closer look';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirmed ${result.confirmed}$skipped')));
  if (result.mismatches.isNotEmpty) await _offerBalanceMatch(context, result.mismatches);
}

/// Lists each wallet whose balance differs from its latest SMS and, if the
/// user agrees, adjusts the wallets to match. Transactions are untouched;
/// the opening balance absorbs the difference.
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

/// One waiting message: what happened, who with, when, the suggested
/// wallet/category as chips (plus fee, pending and possible-duplicate
/// flags), and Confirm / Edit / Ignore. Tapping the card opens the editor.
class _CaptureCard extends StatelessWidget {
  final Capture capture;
  final Future<bool> Function() onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onIgnore;

  const _CaptureCard({required this.capture, required this.onConfirm, required this.onEdit, required this.onIgnore});

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
    // The provider's own wallet: where money arrived for incoming transfers,
    // otherwise where it left.
    final providerWallet = m.kind.isMoneyIn && d.type == TxType.transfer ? d.toWalletId : d.walletId;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onEdit,
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
                      onTap: onEdit,
                    )
                  else
                    _Chip(
                      icon: Icons.category_outlined,
                      label: 'Choose category',
                      color: AppColors.warning,
                      onTap: onEdit,
                    ),
                  if (d.fee > 0)
                    _Chip(icon: Icons.receipt_long, label: '+ fee ${captureMoney(d.fee, symbol)}', color: AppColors.mutedForeground),
                  if (m.pending) const _Chip(icon: Icons.schedule, label: 'Pending', color: AppColors.mutedForeground),
                  if (duplicate != null)
                    const _Chip(icon: Icons.content_copy_outlined, label: 'Already recorded?', color: AppColors.warning),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Confirm',
                      doneLabel: 'Saved',
                      icon: Icons.check,
                      height: 40,
                      onPressed: onConfirm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onIgnore,
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

/// The waiting cards. One that leaves the list (confirmed, ignored) stays a
/// moment to show its result, then folds away instead of vanishing.
class _CaptureList extends StatefulWidget {
  final List<Capture> pending;
  final Widget Function(Capture) itemBuilder;

  const _CaptureList({required this.pending, required this.itemBuilder});

  @override
  State<_CaptureList> createState() => _CaptureListState();
}

class _CaptureListState extends State<_CaptureList> {
  /// Captures on their way out, with the place they had in the list.
  final _leaving = <String, (int, Capture)>{};

  /// Compares the old and new pending lists. Any card that disappeared is
  /// kept in [_leaving] (at its old position) long enough to play the
  /// exit animation, then dropped.
  @override
  void didUpdateWidget(_CaptureList old) {
    super.didUpdateWidget(old);
    final now = {for (final c in widget.pending) c.id};
    _leaving.removeWhere((id, _) => now.contains(id)); // back after an undo
    for (var i = 0; i < old.pending.length; i++) {
      final c = old.pending[i];
      if (now.contains(c.id) || _leaving.containsKey(c.id)) continue;
      _leaving[c.id] = (i, c);
      Future<void>.delayed(_Leaving.total, () {
        if (mounted) setState(() => _leaving.remove(c.id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <(Capture, bool)>[for (final c in widget.pending) (c, false)];
    final leaving = _leaving.values.toList()..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (index, c) in leaving) {
      items.insert(index.clamp(0, items.length), (c, true));
    }
    return Column(
      children: [
        for (final (c, isLeaving) in items)
          _Leaving(
            key: ValueKey(c.id),
            leaving: isLeaving,
            // A saved card holds still for its check mark; an ignored one goes at once.
            hold: c.record.status == CaptureStatus.confirmed,
            child: Padding(padding: const EdgeInsets.only(bottom: 12), child: widget.itemBuilder(c)),
          ),
      ],
    );
  }
}

/// Wraps one card and plays its exit: optionally hold with a green "Saved"
/// overlay, then fade, slide right and fold the height to zero.
class _Leaving extends StatefulWidget {
  /// True once the card has left the pending list.
  final bool leaving;

  /// Pause on the "Saved" overlay before folding (confirmed cards only).
  final bool hold;
  final Widget child;

  const _Leaving({super.key, required this.leaving, required this.hold, required this.child});

  static const _holdFor = Duration(milliseconds: 450);
  static const _foldFor = Duration(milliseconds: 320);

  /// Hold + fold + a small margin; how long _CaptureList keeps a leaving
  /// card around.
  static const total = Duration(milliseconds: 450 + 320 + 60);

  @override
  State<_Leaving> createState() => _LeavingState();
}

class _LeavingState extends State<_Leaving> with SingleTickerProviderStateMixin {
  /// 1 = fully shown, 0 = folded away.
  late final _controller = AnimationController(vsync: this, value: 1, duration: _Leaving._foldFor);

  @override
  void didUpdateWidget(_Leaving old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      Future<void>.delayed(widget.hold ? _Leaving._holdFor : Duration.zero, () {
        if (mounted && widget.leaving) _controller.animateTo(0, curve: Curves.easeInCubic);
      });
    } else if (!widget.leaving && old.leaving) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.leaving && widget.hold
        ? Stack(
            children: [
              widget.child,
              Positioned.fill(
                bottom: 12, // the gap under the card
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 160),
                  builder: (_, t, child) => Opacity(opacity: t, child: child),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
                        SizedBox(width: 10),
                        Text('Saved', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : widget.child;
    // Folds upwards: ClipRect + Align works on every Flutter version (the
    // newer SizeTransition alignment API doesn't exist on older ones).
    return IgnorePointer(
      ignoring: widget.leaving,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => ClipRect(
          child: Align(alignment: Alignment.topCenter, heightFactor: _controller.value, child: child),
        ),
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(_controller),
            child: card,
          ),
        ),
      ),
    );
  }
}

/// One tap to pick a category and confirm.
class _CategoryPicker extends StatelessWidget {
  final Capture capture;
  final TxType type;

  const _CategoryPicker({required this.capture, required this.type});

  /// Returned instead of a category ID when the user wants the full editor.
  static const moreOptions = '__more__';

  static Future<String?> show(BuildContext context, Capture c, TxType type) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CategoryPicker(capture: c, type: type),
      );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final m = capture.message;
    final symbol = vm.settings.currencySymbol;
    final who = m.counterparty == null ? '' : (m.kind.isMoneyIn ? ' from ${m.counterparty}' : ' to ${m.counterparty}');
    // Material (not a coloured Container) so the categories' ripples show.
    return SafeArea(
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick a category to confirm',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('${m.kind.label} ${captureMoney(m.amount, symbol)}$who',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (m.counterparty != null)
              Text('Next time, ${m.counterparty} gets this category automatically.',
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
              children: [
                for (final cat in vm.categoriesOf(type))
                  InkWell(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    onTap: () => Navigator.pop(context, cat.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: Color(cat.color).withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(cat.iconData, color: Color(cat.color), size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, moreOptions),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit other details'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Small tinted label with an icon; tappable when [onTap] is set.
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

/// A confirmed or ignored message from the last week, with Undo.
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

/// Pitch and "Turn on" button, shown while auto-capture is off.
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

/// Header ⋮ menu (only while on): rescan the last 30 days, or turn off.
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

/// Tinted notice with an icon and an optional action button.
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
