import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/frequency.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final TxRecord? edit;

  const AddTransactionScreen({super.key, this.edit});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  TxType _type = TxType.expense;
  String? _categoryId;
  String _walletId = '';
  String? _toWalletId;
  DateTime _dateTime = DateTime.now();
  String? _receiptPath;
  Frequency _frequency = Frequency.once;
  bool _saving = false;

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
  void initState() {
    super.initState();
    final edit = widget.edit;
    _amountCtrl =
        TextEditingController(text: edit == null ? '' : _fmtAmount(edit.amount));
    if (edit != null) {
      _type = edit.type;
      _categoryId = edit.categoryId.isEmpty ? null : edit.categoryId;
      _walletId = edit.walletId;
      _toWalletId = edit.toWalletId;
      _dateTime = edit.dateTime;
      _noteCtrl.text = edit.note;
      _receiptPath = edit.receiptPath;
      _frequency = edit.frequency;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmtAmount(double a) => a.toStringAsFixed(a % 1 == 0 ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final theme = Theme.of(context);
    final symbol = vm.settings.currencySymbol;

    if (_walletId.isEmpty && vm.wallets.isNotEmpty) {
      _walletId = vm.wallets.first.id;
    }
    if (_toWalletId == null && vm.wallets.length > 1) {
      _toWalletId = vm.wallets[1].id;
    }
    if (_toWalletId == null && vm.wallets.isNotEmpty) {
      _toWalletId = vm.wallets.first.id;
    }

    final categories = _type == TxType.income
        ? vm.incomeCategories
        : _type == TxType.expense
            ? vm.expenseCategories
            : <Category>[];

    final isTransfer = _type == TxType.transfer;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTransfer
            ? 'Transfer'
            : _type == TxType.income
                ? 'Add income'
                : 'Add ${widget.edit != null ? 'edit ' : ''}expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Expense')),
                  ButtonSegment(value: TxType.income, label: Text('Income')),
                  ButtonSegment(value: TxType.transfer, label: Text('Transfer')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    symbol,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: widget.edit == null,
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              if (!isTransfer) ...[
                const _Label('CATEGORY'),
                const SizedBox(height: 10),
                if (categories.isEmpty)
                  const Text('No categories. Add some in Settings.')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final selected = _categoryId == cat.id;
                      return InkWell(
                        onTap: () => setState(() => _categoryId = cat.id),
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Color(cat.color)
                                    : Color(cat.color).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: Color(cat.color), width: 2)
                                    : null,
                              ),
                              child: Icon(
                                cat.iconData,
                                color: selected ? Colors.white : Color(cat.color),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],

              const _Label('WALLET'),
              const SizedBox(height: 10),
              if (isTransfer)
                vm.wallets.length < 2
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You need at least two wallets to make a transfer. Please add another wallet in Settings first.',
                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _WalletPair(
                        fromId: _walletId,
                        toId: _toWalletId ?? (vm.wallets.length > 1 ? vm.wallets[1].id : vm.wallets.first.id),
                        wallets: vm.wallets,
                        onFrom: (id) => setState(() => _walletId = id),
                        onTo: (id) => setState(() => _toWalletId = id),
                      )
              else
                _WalletChips(
                  wallets: vm.wallets,
                  selectedId: _walletId,
                  onSelect: (id) => setState(() => _walletId = id),
                ),
              const SizedBox(height: 20),

              const _Label('NOTE'),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Java House'),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(_fmtDateTime(_dateTime)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickReceipt,
                      icon: Icon(
                        _receiptPath != null
                            ? Icons.check_circle_outline
                            : Icons.camera_alt_outlined,
                        color: _receiptPath != null ? AppColors.success : null,
                      ),
                      label: Text(_receiptPath != null ? 'Receipt added' : 'Attach receipt'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (!isTransfer) ...[
                const SizedBox(height: 14),
                const _Label('HOW OFTEN'),
                const SizedBox(height: 10),
                DropdownButtonFormField<Frequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.repeat),
                    hintText: 'How often does this happen?',
                  ),
                  items: [
                    for (final f in _frequencyOptions)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _frequency = v);
                  },
                ),
              ],

              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(isTransfer ? 'Transfer' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      _dateTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final receipts = Directory('${dir.path}/receipts');
    if (!await receipts.exists()) {
      await receipts.create(recursive: true);
    }
    final dest = File('${receipts.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.saveTo(dest.path);
    setState(() => _receiptPath = dest.path);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _toast('Enter a valid amount');
      return;
    }
    if (!isTransferLike && (_categoryId == null || _categoryId!.isEmpty)) {
      _toast('Pick a category');
      return;
    }
    if (isTransferLike) {
      final vm = context.read<TrackerViewModel>();
      if (vm.wallets.length < 2 || _toWalletId == null || _toWalletId!.isEmpty) {
        _toast('Transfer requires at least 2 wallets');
        return;
      }
      if (_walletId == _toWalletId) {
        _toast('Choose two different wallets');
        return;
      }
    }
    try {
      setState(() => _saving = true);
      final vm = context.read<TrackerViewModel>();
      final existing = widget.edit;
      final tx = TxRecord(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        amount: amount,
        walletId: _walletId,
        toWalletId: isTransferLike ? _toWalletId : null,
        categoryId: _categoryId ?? '',
        note: _noteCtrl.text.trim(),
        dateTime: _dateTime,
        receiptPath: _receiptPath,
        frequency: isTransferLike ? Frequency.once : _frequency,
      );
      if (existing != null) {
        await vm.updateTransaction(tx);
      } else {
        await vm.addTransaction(tx);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('Error saving transaction: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get isTransferLike => _type == TxType.transfer;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  $h:$m';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
    );
  }
}

class _WalletChips extends StatelessWidget {
  final List<Wallet> wallets;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _WalletChips({
    required this.wallets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final w in wallets)
          ChoiceChip(
            avatar: Icon(w.type.icon, size: 18),
            label: Text(w.name),
            selected: w.id == selectedId,
            onSelected: (_) => onSelect(w.id),
          ),
      ],
    );
  }
}

class _WalletPair extends StatelessWidget {
  final String fromId;
  final String toId;
  final List<Wallet> wallets;
  final ValueChanged<String> onFrom;
  final ValueChanged<String> onTo;

  const _WalletPair({
    required this.fromId,
    required this.toId,
    required this.wallets,
    required this.onFrom,
    required this.onTo,
  });

  @override
  Widget build(BuildContext context) {
    Wallet walletOf(String id) =>
        wallets.firstWhere((w) => w.id == id, orElse: () => wallets.first);

    DropdownMenu<Wallet> menu(String selected, ValueChanged<String> cb, double menuWidth) {
      final sel = walletOf(selected);
      return DropdownMenu<Wallet>(
        width: menuWidth,
        initialSelection: sel,
        label: const Text('Wallet'),
        onSelected: (w) => cb(w!.id),
        dropdownMenuEntries: [
          for (final w in wallets)
            DropdownMenuEntry(value: w, label: w.name, leadingIcon: Icon(w.type.icon, size: 18)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 28;
        final half = (available / 2).clamp(120.0, 180.0);
        return Row(
          children: [
            Expanded(child: menu(fromId, onFrom, half)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 18),
            ),
            Expanded(child: menu(toId, onTo, half)),
          ],
        );
      },
    );
  }
}