import 'package:flutter/material.dart';

import '../format/money_format.dart';
import '../format/money_input.dart';
import '../theme/app_theme.dart';

/// Dashboard card for setting a monthly spending limit and visualizing how
/// much budget remains for the current month.
class MonthlyBudgetCard extends StatelessWidget {
  final double spent;
  final double limit;
  final bool hasCustomLimit;
  final String symbol;
  final ValueChanged<double?> onSaveLimit;

  const MonthlyBudgetCard({
    super.key,
    required this.spent,
    required this.limit,
    required this.hasCustomLimit,
    required this.symbol,
    required this.onSaveLimit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasLimit = limit > 0;
    final ratio = hasLimit ? spent / limit : 0.0;
    final remaining = limit - spent;
    final isOver = hasLimit && remaining < 0;

    // Color-code progress so the user gets an early visual cue at 80% and over 100%.
    final statusColor = !hasLimit
        ? c.mutedForeground
        : isOver
            ? AppColors.danger
            : ratio >= 0.8
                ? AppColors.warning
                : c.primary;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Monthly spending limit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('set_monthly_limit_button'),
                  onPressed: () => _showLimitDialog(context),
                  icon: Icon(
                    hasLimit ? Icons.edit_outlined : Icons.tune_rounded,
                    size: 16,
                  ),
                  label: Text(hasLimit ? 'Edit limit' : 'Set limit'),
                  style: TextButton.styleFrom(
                    foregroundColor: c.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (!hasLimit) ...[
              const SizedBox(height: 8),
              Text(
                'Set a monthly limit to track how much budget you have left this month.',
                style: TextStyle(
                  fontSize: 12,
                  color: c.mutedForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLimitDialog(context),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: const Text('Set monthly spending limit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      isOver
                          ? '${MoneyFormat.money(remaining.abs(), symbol: symbol)} over limit'
                          : '${MoneyFormat.money(remaining, symbol: symbol)} remaining',
                      key: const Key('remaining_budget_text'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}% used',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${MoneyFormat.money(spent, symbol: symbol)} of ${MoneyFormat.money(limit, symbol: symbol)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.mutedForeground,
                      ),
                    ),
                  ),
                  Text(
                    hasCustomLimit ? 'Custom limit' : 'Category budgets',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens a dialog allowing the user to enter or clear their monthly limit.
  Future<void> _showLimitDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _MonthlyLimitDialog(
        initialLimit: limit,
        hasCustomLimit: hasCustomLimit,
        symbol: symbol,
        onSaveLimit: onSaveLimit,
      ),
    );
  }
}

/// Dialog that owns and disposes its [TextEditingController] safely across
/// the route's closing animation.
class _MonthlyLimitDialog extends StatefulWidget {
  final double initialLimit;
  final bool hasCustomLimit;
  final String symbol;
  final ValueChanged<double?> onSaveLimit;

  const _MonthlyLimitDialog({
    required this.initialLimit,
    required this.hasCustomLimit,
    required this.symbol,
    required this.onSaveLimit,
  });

  @override
  State<_MonthlyLimitDialog> createState() => _MonthlyLimitDialogState();
}

class _MonthlyLimitDialogState extends State<_MonthlyLimitDialog> {
  late final TextEditingController _ctrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialLimit > 0 ? MoneyInput.text(widget.initialLimit) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly spending limit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set the maximum amount you want to spend each month.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('monthly_limit_input'),
            controller: _ctrl,
            autofocus: true,
            keyboardType: MoneyInput.keyboardType,
            inputFormatters: MoneyInput.formatters,
            decoration: InputDecoration(
              labelText: 'Monthly limit (${widget.symbol})',
              hintText: 'e.g. 500,000',
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hasCustomLimit)
          TextButton(
            onPressed: () {
              widget.onSaveLimit(null);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save_monthly_limit_button'),
          onPressed: () {
            final parsed = double.tryParse(_ctrl.text.replaceAll(',', '').trim());
            if (parsed == null || parsed <= 0) {
              setState(() {
                _errorText = 'Enter an amount greater than 0';
              });
              return;
            }
            widget.onSaveLimit(parsed);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
