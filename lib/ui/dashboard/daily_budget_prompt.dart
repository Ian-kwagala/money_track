import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

/// One-time prompt (shown once, right after the profile-completion sheet if
/// that also fires) asking the user to set a daily spending target. Runs
/// only while [AppSettings.dailyBudget] is unset.
class DailyBudgetPrompt {
  static Future<void> maybeShow(BuildContext context) async {
    final vm = context.read<TrackerViewModel>();
    if (vm.settings.dailyBudget != null) return;

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DailyBudgetSheet(),
    );
  }
}

class _DailyBudgetSheet extends StatefulWidget {
  const _DailyBudgetSheet();

  @override
  State<_DailyBudgetSheet> createState() => _DailyBudgetSheetState();
}

class _DailyBudgetSheetState extends State<_DailyBudgetSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final vm = context.read<TrackerViewModel>();
    final totalBudget = vm.budgets.fold<double>(0, (sum, b) => sum + b.amount);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final income = vm.incomeTotal(monthStart, now);
    final suggested = totalBudget > 0 ? totalBudget / 30 : (income > 0 ? income / 30 : 20000.0);
    _ctrl = TextEditingController(text: suggested.round().toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.today_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 12),
              const Text('Set a daily spending target', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                "We'll track your spending against this each day and let you know when you're close to going over.",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Daily budget ($symbol)',
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final v = double.tryParse(_ctrl.text.replaceAll(',', ''));
                    final s = vm.settings;
                    s.dailyBudget = (v != null && v > 0) ? v : 20000.0;
                    await vm.updateSettings(s);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  // Skipping still needs a value so the prompt doesn't fire on every
                  // launch; fall back to the suggested amount already in the field.
                  final v = double.tryParse(_ctrl.text.replaceAll(',', '')) ?? 20000.0;
                  final s = vm.settings;
                  s.dailyBudget = v;
                  await vm.updateSettings(s);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Use suggested amount', style: TextStyle(color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
