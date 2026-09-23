import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

/// Runs once (tracked via [SharedPreferences]) after onboarding to nudge the
/// user into finishing their profile — full name, date of birth, occupation
/// and wallet balances — without blocking them from using the app.
class CompletenessCheck {
  static const _shownKey = 'profileCompletionShown';

  static Future<void> maybeShow(BuildContext context) async {
    final vm = context.read<TrackerViewModel>();
    if (vm.currentUser.dateOfBirth != null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;
    await prefs.setBool(_shownKey, true);

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileCompletionSheet(),
    );
  }
}

class ProfileCompletionSheet extends StatefulWidget {
  const ProfileCompletionSheet({super.key});

  @override
  State<ProfileCompletionSheet> createState() => _ProfileCompletionSheetState();
}

class _ProfileCompletionSheetState extends State<ProfileCompletionSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _occupationCtrl;
  final Map<String, TextEditingController> _balanceCtrls = {};
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<TrackerViewModel>();
    final user = vm.currentUser;
    _nameCtrl = TextEditingController(text: user.name);
    _occupationCtrl = TextEditingController(text: user.occupation ?? '');
    _dateOfBirth = user.dateOfBirth;
    for (final w in vm.wallets) {
      _balanceCtrls[w.id] = TextEditingController(
        text: w.currentBalance == 0 ? '' : w.currentBalance.toStringAsFixed(w.currentBalance % 1 == 0 ? 0 : 2),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _occupationCtrl.dispose();
    for (final c in _balanceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _age {
    final dob = _dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
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
                  const Expanded(
                    child: Text('Complete your profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('A few more details help us personalize your budgets. You can always skip this.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    const Text('Full name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Date of birth', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
                          firstDate: DateTime(now.year - 100),
                          lastDate: DateTime(now.year - 10, now.month, now.day),
                        );
                        if (picked != null) setState(() => _dateOfBirth = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              _dateOfBirth == null ? 'Not set' : '${DateFormat('d MMM yyyy').format(_dateOfBirth!)} · age $_age',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Occupation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _occupationCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Teacher, Shop owner',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    if (vm.wallets.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Wallet balances', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      for (final w in vm.wallets) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(w.name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 130,
                                child: TextField(
                                  controller: _balanceCtrls[w.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    prefixText: '$symbol ',
                                    filled: true,
                                    fillColor: AppColors.bg,
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 8, 20, media.viewInsets.bottom + 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip for now', style: TextStyle(color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
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
    setState(() => _saving = true);
    final vm = context.read<TrackerViewModel>();
    final user = vm.currentUser;
    if (_nameCtrl.text.trim().isNotEmpty) user.name = _nameCtrl.text.trim();
    user.occupation = _occupationCtrl.text.trim();
    user.dateOfBirth = _dateOfBirth;
    await vm.saveUser(user);

    for (final w in vm.wallets) {
      final text = _balanceCtrls[w.id]?.text ?? '';
      final bal = double.tryParse(text.replaceAll(',', ''));
      if (bal != null) {
        w.openingBalance = bal;
        w.currentBalance = bal;
        await vm.saveWallet(w);
      }
    }

    if (mounted) Navigator.pop(context);
  }
}
