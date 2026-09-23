import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/income_profile.dart';
import '../../models/wallet.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _monthlyIncomeCtrl;
  late String _incomeSource;
  late IncomeFrequency _incomeFrequency;
  late bool _isVariable;
  DateTime? _lastPayDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<TrackerViewModel>();
    final user = vm.currentUser;
    _nameCtrl = TextEditingController(text: user.name);
    _phoneCtrl = TextEditingController(text: user.phone);
    _emailCtrl = TextEditingController(text: user.email);
    _occupationCtrl = TextEditingController(text: user.occupation ?? '');
    _monthlyIncomeCtrl = TextEditingController(text: user.expectedMonthlyIncome > 0 ? user.expectedMonthlyIncome.toStringAsFixed(0) : '');
    _incomeSource = user.incomeSource.isEmpty ? 'salary' : user.incomeSource;
    _incomeFrequency = user.incomeFrequency;
    _isVariable = user.isVariable;
    _lastPayDate = user.lastPayDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _occupationCtrl.dispose();
    _monthlyIncomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username is required')));
      return;
    }
    setState(() => _saving = true);
    final vm = context.read<TrackerViewModel>();
    await vm.updateAccountDetails(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      incomeSource: _incomeSource,
      occupation: _occupationCtrl.text.trim(),
      incomeFrequency: _incomeFrequency,
      expectedMonthlyIncome: double.tryParse(_monthlyIncomeCtrl.text.replaceAll(',', '')),
      isVariable: _isVariable,
      lastPayDate: _lastPayDate,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account updated')));
      Navigator.pop(context);
    }
  }

  Future<void> _changePin() async {
    final vm = context.read<TrackerViewModel>();
    final currentPin = vm.settings.appLockPin ?? '';
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vm.settings.appLockEnabled && currentPin.isNotEmpty) ...[
                TextField(
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {},
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'New PIN (4-6 digits)',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: () => setState(() => obscure = !obscure)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Confirm new PIN',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (pinCtrl.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be at least 4 digits')));
                  return;
                }
                if (pinCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await vm.setAppLock(pin: pinCtrl.text, enabled: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN updated. Required on every sign in.')));
      setState(() {});
    }
  }

  Future<void> _showAddWalletDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    WalletType selectedType = WalletType.cash;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Wallet name', hintText: 'e.g. Equity Bank', filled: true, fillColor: AppColors.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              DropdownButtonFormField<WalletType>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: 'Type', filled: true, fillColor: AppColors.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: WalletType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() => selectedType = v ?? WalletType.cash),
              ),
              const SizedBox(height: 12),
              TextField(controller: balanceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Initial balance (UGX)', hintText: '0', filled: true, fillColor: AppColors.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result != true || nameCtrl.text.trim().isEmpty) return;
    if (!context.mounted) return;
    final wallet = Wallet(
      id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim(),
      type: selectedType,
      color: const Color(0xFF0B8457).toARGB32(),
      openingBalance: double.tryParse(balanceCtrl.text.replaceAll(',', '')) ?? 0,
      currentBalance: double.tryParse(balanceCtrl.text.replaceAll(',', '')) ?? 0,
    );
    await context.read<TrackerViewModel>().saveWallet(wallet);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wallet "${wallet.name}" added')));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final s = vm.settings;
    final user = vm.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Account & Security', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header profile
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.name.isEmpty ? 'Ian' : user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(user.phone.isEmpty ? 'No phone' : user.phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        if (user.email.isNotEmpty) Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
                      child: Text(user.incomeSource == 'informal' ? 'Informal' : 'Salary', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Account details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Update your personal information and income source.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    const Text('Username *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '+256 700 000000',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'email@example.com',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Source of income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _incomeSource = 'salary'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _incomeSource == 'salary' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _incomeSource == 'salary' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.work_outline, size: 16, color: _incomeSource == 'salary' ? AppColors.primary : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text('Salary', style: TextStyle(fontWeight: FontWeight.w600, color: _incomeSource == 'salary' ? AppColors.primary : AppColors.textSecondary)),
                                ]),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _incomeSource = 'informal'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _incomeSource == 'informal' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _incomeSource == 'informal' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.handyman_outlined, size: 16, color: _incomeSource == 'informal' ? AppColors.primary : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text('Informal', style: TextStyle(fontWeight: FontWeight.w600, color: _incomeSource == 'informal' ? AppColors.primary : AppColors.textSecondary)),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Occupation / Business type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _occupationCtrl,
                      decoration: InputDecoration(
                        hintText: _incomeSource == 'salary' ? 'e.g. Teacher' : 'e.g. Shop owner',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Average monthly income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _monthlyIncomeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 2,500,000',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('How often are you paid?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<IncomeFrequency>(
                      initialValue: _incomeFrequency,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      items: [for (final f in IncomeFrequency.values) DropdownMenuItem(value: f, child: Text(f.label))],
                      onChanged: (v) {
                        if (v != null) setState(() => _incomeFrequency = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('My income varies month to month', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        Switch(value: _isVariable, onChanged: (v) => setState(() => _isVariable = v), activeThumbColor: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Last payday', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Used to know when to ask if you’ve been paid again.', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _lastPayDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _lastPayDate = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              _lastPayDate == null ? 'Not set' : DateFormat('d MMM yyyy').format(_lastPayDate!),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primaryDark, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Protect your financial data with a PIN required on every sign in.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 18)),
                        const SizedBox(width: 12),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('App lock', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)), Text('Require PIN on every open', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
                        Switch(
                          value: s.appLockEnabled,
                          onChanged: (v) async {
                            if (v && (s.appLockPin == null || s.appLockPin!.isEmpty)) {
                              await _changePin();
                            } else {
                              await vm.setAppLock(pin: s.appLockPin ?? '', enabled: v);
                              if (mounted) setState(() {});
                            }
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _changePin,
                        icon: const Icon(Icons.key_outlined, size: 16),
                        label: Text(s.appLockEnabled && s.appLockPin != null && s.appLockPin!.isNotEmpty ? 'Change PIN' : 'Set PIN'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.divider)),
                      ),
                    ),
                    if (s.appLockEnabled) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDBEAFE))),
                        child: const Row(children: [Icon(Icons.info_outline, size: 14, color: Color(0xFF2563EB)), SizedBox(width: 6), Expanded(child: Text('Your data will be locked and require PIN on every launch.', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))))]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wallets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    for (final w in vm.wallets)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(w.color).withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(w.type.icon, color: Color(w.color), size: 16)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)), Text('UGX ${w.currentBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
                          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showAddWalletDialog(context),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.divider)),
                        child: const Text('+ Add wallet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.logout, color: AppColors.danger, size: 18)), const SizedBox(width: 12), const Expanded(child: Text('Lock now', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary))), FilledButton(onPressed: () { vm.lock(); Navigator.pop(context); }, style: FilledButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Lock', style: TextStyle(color: Colors.white)))]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Clear all data?'), content: const Text('This removes transactions and resets account.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Clear'))]));
                          if (ok == true) {
                            await vm.clearAll();
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared')));
                          }
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.danger)),
                        child: const Text('Clear all data', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
