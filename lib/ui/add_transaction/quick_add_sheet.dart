import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

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
  String _amountDisplay = '0';
  bool _saving = false;

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
                            '$symbol $_amountDisplay',
                            style: TextStyle(fontSize: isSmall ? 28 : 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1),
                          ),
                          Text(' UGX', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt picker — attach photo from camera/gallery'))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Attach receipt', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
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
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9DBFB1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Save transaction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

  Future<void> _save() async {
    final amount = double.tryParse(_amountDisplay.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a category')));
      return;
    }
    final vm = context.read<TrackerViewModel>();
    if (vm.wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a wallet first')));
      return;
    }
    setState(() => _saving = true);
    final tx = TxRecord(id: DateTime.now().microsecondsSinceEpoch.toString(), type: _type, amount: amount, walletId: _walletId, categoryId: _categoryId ?? '', note: _noteCtrl.text.trim(), dateTime: DateTime.now());
    await vm.addTransaction(tx);
    if (mounted) Navigator.pop(context);
  }
}

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

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final bool isSmall;
  const _Numpad({required this.onKey, this.isSmall = false});
  @override
  Widget build(BuildContext context) {
    Widget key(String label, {IconData? icon, VoidCallback? tap}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: GestureDetector(
            onTap: tap ?? () => onKey(label),
            child: Container(
              height: isSmall ? 42 : 48,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: AppColors.textSecondary, size: 18)
                    : Text(label, style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
