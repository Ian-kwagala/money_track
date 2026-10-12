import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/capture/money_message.dart';
import '../../services/capture/money_message_parser.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

/// Paste an SMS and see what auto-capture reads from it. Nothing is saved:
/// it's for checking the parser against real messages before automatic
/// reading is switched on.
class CheckMessageSheet extends StatefulWidget {
  const CheckMessageSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const CheckMessageSheet(),
      );

  @override
  State<CheckMessageSheet> createState() => _CheckMessageSheetState();
}

class _CheckMessageSheetState extends State<CheckMessageSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    setState(() => _ctrl.text = text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text.trim();
    final parsed = text.isEmpty ? null : const MoneyMessageParser().parse(text, receivedAt: DateTime.now());

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
              const Text('Check a message',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                'Paste an MTN, Airtel or bank SMS to see what MoneyTrack reads from it. Nothing is saved.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'e.g. SENT UGX 21,000 to … TID …',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('Paste'),
                  ),
                  if (text.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_ctrl.clear),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                parsed == null ? const _NotRecognised() : _ParsedCard(parsed),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotRecognised extends StatelessWidget {
  const _NotRecognised();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, color: AppColors.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not recognised as a money message. If it is one, send it to the developer so it can be added.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedCard extends StatelessWidget {
  final ParsedMoneyMessage m;
  const _ParsedCard(this.m);

  static String _ugx(double v) => MoneyFormat.money(v, symbol: 'UGX', decimals: v == v.roundToDouble() ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final color = m.kind.isMoneyIn ? AppColors.income : AppColors.danger;
    final at = m.occurredAt;
    final rows = <(String, String?)>[
      ('From', m.provider.label),
      (m.kind.isMoneyIn ? 'Paid by' : 'Paid to', m.counterparty),
      ('Number', m.counterpartyNumber),
      ('Fee', m.fee > 0 ? _ugx(m.fee) : null),
      ('Balance after', m.balance == null ? null : _ugx(m.balance!)),
      ('Transaction ID', m.reference),
      ('Date', at == null ? null : '${MoneyFormat.shortDay(at)} ${at.year} · ${MoneyFormat.timeShort(at)}'),
      ('Account', m.account),
      if (m.pending) ('Status', 'Pending — not settled yet'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${m.kind.label} · ${_ugx(m.amount)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            if (value != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Text(value,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
