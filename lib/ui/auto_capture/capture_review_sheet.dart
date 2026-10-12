import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../services/capture/capture_service.dart';
import '../../services/capture/capture_suggestions.dart';
import '../../services/capture/money_message.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

/// What happened in a [CaptureReviewSheet].
class CaptureOutcome {
  final bool confirmed;
  final BalanceMismatch? mismatch;

  const CaptureOutcome.confirmed(this.mismatch) : confirmed = true;
  const CaptureOutcome.ignored()
      : confirmed = false,
        mismatch = null;
}

String captureMoney(double v, String symbol) =>
    MoneyFormat.money(v, symbol: symbol, decimals: v == v.roundToDouble() ? 0 : 2);

/// Full review of one captured SMS: type, wallets, category and note can all
/// be changed before confirming, and the original message is shown.
class CaptureReviewSheet extends StatefulWidget {
  final Capture capture;

  const CaptureReviewSheet({super.key, required this.capture});

  static Future<CaptureOutcome?> show(BuildContext context, Capture capture) =>
      showModalBottomSheet<CaptureOutcome>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CaptureReviewSheet(capture: capture),
      );

  @override
  State<CaptureReviewSheet> createState() => _CaptureReviewSheetState();
}

class _CaptureReviewSheetState extends State<CaptureReviewSheet> {
  late final CaptureDraft _d;
  late final TextEditingController _note;
  bool _busy = false;

  ParsedMoneyMessage get _m => widget.capture.message;

  @override
  void initState() {
    super.initState();
    _d = context.read<CaptureService>().draftFor(widget.capture);
    _note = TextEditingController(text: _d.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _setType(TxType type, List<Wallet> wallets) {
    setState(() {
      if (type == TxType.transfer && _d.type != TxType.transfer) {
        final provider = _d.walletId;
        String? other;
        for (final w in wallets) {
          if (w.id != provider) {
            other = w.id;
            break;
          }
        }
        // Keep the provider's wallet on the side the money actually moved.
        _d.walletId = _m.kind.isMoneyIn ? other : provider;
        _d.toWalletId = _m.kind.isMoneyIn ? provider : other;
      } else if (type != TxType.transfer && _d.type == TxType.transfer) {
        _d.walletId = _m.kind.isMoneyIn ? _d.toWalletId : _d.walletId;
        _d.toWalletId = null;
      }
      _d.type = type;
      _d.categoryId = type == TxType.transfer ? null : context.read<CaptureService>().suggestions.categoryFor(_m, type);
    });
  }

  /// A wallet for a provider the user doesn't have one for yet (e.g. NSSF).
  Future<void> _createWallet() async {
    final vm = context.read<TrackerViewModel>();
    final type = switch (_m.provider) {
      MoneyProvider.centenary => WalletType.bank,
      MoneyProvider.nssfSmartlife => WalletType.savings,
      _ => WalletType.mobileMoney,
    };
    final wallet = Wallet(
      id: 'wallet_${_m.provider.name}_${DateTime.now().millisecondsSinceEpoch}',
      name: _m.provider.label,
      type: type,
      icon: switch (type) { WalletType.bank => 'bank', WalletType.savings => 'savings', _ => 'mobile' },
      color: AppColors.primary.toARGB32(),
      openingBalance: 0,
      currentBalance: 0,
    );
    await vm.saveWallet(wallet);
    setState(() {
      if (_d.type == TxType.transfer && _m.kind.isMoneyIn) {
        _d.toWalletId = wallet.id;
      } else {
        _d.walletId = wallet.id;
      }
    });
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final service = context.read<CaptureService>();
    _d.note = _note.text.trim().isEmpty ? _d.note : _note.text.trim();
    final mismatch = await service.confirm(widget.capture, _d);
    if (mounted) Navigator.pop(context, CaptureOutcome.confirmed(mismatch));
  }

  Future<void> _ignore() async {
    setState(() => _busy = true);
    await context.read<CaptureService>().ignore(widget.capture);
    if (mounted) Navigator.pop(context, const CaptureOutcome.ignored());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final service = context.read<CaptureService>();
    final symbol = vm.settings.currencySymbol;
    final wallets = vm.wallets;
    final categories = _d.type == TxType.transfer ? const <Category>[] : vm.categoriesOf(_d.type);
    final duplicate = service.possibleDuplicate(widget.capture, _d);
    final providerSideEmpty = _d.type == TxType.transfer && _m.kind.isMoneyIn ? _d.toWalletId == null : _d.walletId == null;
    final kindColor = _m.kind.isMoneyIn ? AppColors.income : AppColors.danger;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_m.kind.label} · ${captureMoney(_m.amount, symbol)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kindColor)),
              const SizedBox(height: 4),
              Text(
                '${_m.counterparty ?? _m.provider.label} · ${MoneyFormat.shortDay(_d.dateTime)} ${MoneyFormat.timeShort(_d.dateTime)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Expense')),
                  ButtonSegment(value: TxType.income, label: Text('Income')),
                  ButtonSegment(value: TxType.transfer, label: Text('Transfer')),
                ],
                selected: {_d.type},
                onSelectionChanged: (s) => _setType(s.first, wallets),
              ),
              const SizedBox(height: 16),
              if (_d.type == TxType.transfer) ...[
                _WalletField(
                  label: 'From',
                  value: _d.walletId,
                  wallets: wallets,
                  onChanged: (id) => setState(() => _d.walletId = id),
                ),
                const SizedBox(height: 10),
                _WalletField(
                  label: 'To',
                  value: _d.toWalletId,
                  wallets: wallets,
                  onChanged: (id) => setState(() => _d.toWalletId = id),
                ),
              ] else
                _WalletField(
                  label: 'Wallet',
                  value: _d.walletId,
                  wallets: wallets,
                  onChanged: (id) => setState(() => _d.walletId = id),
                ),
              if (providerSideEmpty)
                TextButton.icon(
                  onPressed: _createWallet,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Create a ${_m.provider.label} wallet'),
                ),
              if (_d.type != TxType.transfer) ...[
                const SizedBox(height: 16),
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        avatar: Icon(c.iconData, size: 16, color: Color(c.color)),
                        label: Text(c.name),
                        selected: _d.categoryId == c.id,
                        onSelected: (_) => setState(() => _d.categoryId = c.id),
                      ),
                  ],
                ),
              ],
              if (_d.fee > 0) ...[
                const SizedBox(height: 14),
                Text(
                  'The ${captureMoney(_d.fee, symbol)} fee is saved as its own expense under Fees & Charges.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                ),
              ),
              if (duplicate != null) ...[
                const SizedBox(height: 14),
                _Notice(
                  color: AppColors.warning,
                  icon: Icons.content_copy_outlined,
                  text: 'You already have a ${captureMoney(duplicate.amount, symbol)} '
                      '${duplicate.type.name} on ${MoneyFormat.shortDay(duplicate.dateTime)}'
                      '${duplicate.note.isEmpty ? '' : ' ("${duplicate.note}")'}. '
                      'Confirm only if this is a different one.',
                ),
              ],
              const SizedBox(height: 16),
              const Text('Original message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                child: Text(widget.capture.record.body, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(onPressed: _busy ? null : _ignore, child: const Text('Ignore')),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy || !_d.isComplete ? null : _confirm,
                    child: const Text('Confirm'),
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

class _WalletField extends StatelessWidget {
  final String label;
  final String? value;
  final List<Wallet> wallets;
  final ValueChanged<String?> onChanged;

  const _WalletField({required this.label, required this.value, required this.wallets, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final known = wallets.any((w) => w.id == value);
    return DropdownButtonFormField<String>(
      // initialValue is only read once; a new key resets it when the draft changes.
      key: ValueKey('$label:$value'),
      initialValue: known ? value : null,
      isExpanded: true,
      hint: const Text('Choose a wallet'),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
      ),
      items: [
        for (final w in wallets)
          DropdownMenuItem(
            value: w.id,
            child: Row(children: [
              Icon(w.type.icon, size: 18, color: Color(w.color)),
              const SizedBox(width: 8),
              Expanded(child: Text(w.name, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Notice({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4))),
        ],
      ),
    );
  }
}
