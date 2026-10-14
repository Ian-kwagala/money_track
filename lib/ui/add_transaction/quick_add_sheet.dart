import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/frequency.dart';
import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';
import '../format/money_format.dart';
import '../format/money_input.dart';
import '../widgets/action_button.dart';
import '../widgets/receipt_picker.dart';

/// The bottom sheet behind the Add button: the fastest way to log an
/// expense or income.
///
/// Built around a phone-style numpad. Pick the type, key in the amount,
/// choose a wallet and one of the first eight categories, optionally a
/// frequency, receipt and note, then save. Transfers and back-dated entries
/// use the full AddTransactionScreen instead.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  TxType _type = TxType.expense;
  String? _categoryId;
  String _walletId = '';
  final _noteCtrl = TextEditingController();

  /// The amount as typed on the numpad, digits only ("25000"); grouped with
  /// commas only for display.
  String _amountDisplay = '0';
  Frequency _frequency = Frequency.once;
  String? _receiptPath;

  /// The record just saved, kept for the Undo snackbar in [_close].
  TxRecord? _saved;

  /// Every frequency except custom, which needs a day count this sheet
  /// doesn't ask for.
  static const _frequencyOptions = [
    Frequency.once,
    Frequency.daily,
    Frequency.weekly,
    Frequency.biweekly,
    Frequency.monthly,
    Frequency.quarterly,
    Frequency.yearly,
    Frequency.random,
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets.bottom;
    final screenH = media.size.height;
    final isSmall = screenH < 700;

    // Default to the first wallet the first time there is one.
    if (_walletId.isEmpty && vm.wallets.isNotEmpty) {
      _walletId = vm.wallets.first.id;
    }

    final categories = _type == TxType.income ? vm.incomeCategories : vm.expenseCategories;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenH * 0.92,
          minHeight: screenH * 0.5,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const Text('Quick add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable middle content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 8, left: 0, right: 0),
                child: Column(
                  children: [
                    // Expense / Income toggle. Switching clears the category,
                    // since the two have different category lists.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {_type = TxType.expense; _categoryId = null;}),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _type == TxType.expense ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: _type == TxType.expense ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Center(child: Text('Expense', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _type == TxType.expense ? AppColors.textPrimary : AppColors.textSecondary))),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {_type = TxType.income; _categoryId = null;}),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _type == TxType.income ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: _type == TxType.income ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Center(child: Text('Income', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _type == TxType.income ? AppColors.textPrimary : AppColors.textSecondary))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 12 : 18),
                    const Text('Amount', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_type == TxType.income)
                            const Text('+ ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          Text(
                            '$symbol ${MoneyInput.group(_amountDisplay)}',
                            style: TextStyle(fontSize: isSmall ? 28 : 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    // Wallet chips, scrolling sideways.
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: vm.wallets.length,
                        itemBuilder: (_, i) {
                          final w = vm.wallets[i];
                          final selected = w.id == _walletId;
                          return GestureDetector(
                            onTap: () => setState(() => _walletId = w.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : AppColors.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
                              ),
                              child: Center(
                                child: Text(w.name,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? AppColors.primary : AppColors.textPrimary)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // Category grid: the first eight only, to keep the sheet
                      // compact.
                      child: GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: isSmall ? 6 : 10,
                        crossAxisSpacing: 8,
                        childAspectRatio: isSmall ? 0.85 : 0.95,
                        children: [
                          for (final cat in categories.take(8))
                            _CatChip(
                              cat: cat,
                              selected: _categoryId == cat.id,
                              onTap: () => setState(() => _categoryId = cat.id),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: _frequencyOptions.length,
                        itemBuilder: (_, i) {
                          final f = _frequencyOptions[i];
                          final selected = f == _frequency;
                          return GestureDetector(
                            onTap: () => setState(() => _frequency = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.bg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.2),
                              ),
                              child: Center(
                                child: Text(
                                  f.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ReceiptPicker(
                          path: _receiptPath,
                          onChanged: (p) => setState(() => _receiptPath = p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _noteCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a note (optional)',
                          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Fixed bottom: numpad + CTA with responsive sizing
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, viewInsets + 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Numpad(
                    isSmall: isSmall,
                    // Edit the typed amount: backspace never goes below "0",
                    // "000" is ignored while the amount is 0, and the first
                    // digit replaces the leading 0.
                    onKey: (key) {
                      setState(() {
                        if (key == 'back') {
                          if (_amountDisplay.length > 1) {
                            _amountDisplay = _amountDisplay.substring(0, _amountDisplay.length - 1);
                          } else {
                            _amountDisplay = '0';
                          }
                        } else if (key == '000') {
                          if (_amountDisplay != '0') _amountDisplay += '000';
                        } else {
                          if (_amountDisplay == '0') {
                            _amountDisplay = key;
                          } else {
                            _amountDisplay += key;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      label: 'Save transaction',
                      doneLabel: 'Saved',
                      icon: Icons.check,
                      // Muted until it's ready; still tappable, to say what's missing.
                      dimmed: !_ready,
                      onPressed: _save,
                      onDone: _close,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _amount => double.tryParse(_amountDisplay.replaceAll(',', '')) ?? 0;

  /// Amount and category set; drives the Save button's dimmed look.
  bool get _ready => _amount > 0 && (_categoryId?.isNotEmpty ?? false);

  /// True once saved; the button then shows its check and [_close] runs.
  Future<bool> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    void tell(String msg) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
    if (_amount <= 0) {
      tell('Enter an amount');
      return false;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      tell('Pick a category');
      return false;
    }
    final vm = context.read<TrackerViewModel>();
    if (vm.wallets.isEmpty) {
      tell('Add a wallet first');
      return false;
    }
    final tx = TxRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: _amount,
      walletId: _walletId,
      categoryId: _categoryId ?? '',
      note: _noteCtrl.text.trim(),
      dateTime: DateTime.now(),
      receiptPath: _receiptPath,
      frequency: _frequency,
    );
    await vm.addTransaction(tx);
    _saved = tx;
    return true;
  }

  /// Closes the sheet and offers Undo.
  void _close() {
    final saved = _saved;
    if (!mounted || saved == null) return;
    final vm = context.read<TrackerViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final category = vm.categoryById(saved.categoryId)?.name;
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Saved · ${MoneyFormat.money(saved.amount, symbol: vm.settings.currencySymbol)}'
            '${category == null ? '' : ' · $category'}'),
        action: SnackBarAction(label: 'Undo', onPressed: () => vm.deleteTransaction(saved.id)),
      ));
  }
}

/// A category as a round icon with its name underneath; ringed when chosen.
class _CatChip extends StatelessWidget {
  final Category cat;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.cat, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(cat.color).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
            ),
            child: Icon(cat.iconData, color: Color(cat.color), size: 18),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// 1-9, "000", 0 and backspace. Reports each press as a string key ('back'
/// for backspace).
class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final bool isSmall;
  const _Numpad({required this.onKey, this.isSmall = false});
  @override
  Widget build(BuildContext context) {
    Widget key(String label, {IconData? icon, VoidCallback? tap}) {
      // A ripple and a light tick on every key, like a phone keypad.
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Material(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                (tap ?? () => onKey(label))();
              },
              child: SizedBox(
                height: isSmall ? 42 : 48,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: AppColors.textSecondary, size: 18)
                      : Text(label, style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [key('1'), key('2'), key('3')]),
        Row(children: [key('4'), key('5'), key('6')]),
        Row(children: [key('7'), key('8'), key('9')]),
        Row(children: [key('000'), key('0'), key('', icon: Icons.backspace_outlined, tap: () => onKey('back'))]),
      ],
    );
  }
}
