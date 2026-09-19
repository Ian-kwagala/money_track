import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/wallet.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _budgetWarnings;
  late bool _billReminders;
  late bool _unusualSpending;
  late bool _weeklySummary;
  late bool _notifAccess;

  @override
  void initState() {
    super.initState();
    // These are local UI preferences (not yet persisted to settings in this version)
    _budgetWarnings = true;
    _billReminders = true;
    _unusualSpending = true;
    _weeklySummary = false;
    _notifAccess = true;
  }

  Future<void> _requestNotificationAccess(bool value) async {
    if (!value) {
      setState(() => _notifAccess = false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow notification access?'),
        content: const Text('MoneyTrack can read money alerts your phone already receives \u2014 MTN, Airtel and bank messages \u2014 so transactions fill themselves in. Nothing is saved until you confirm it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Deny')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() => _notifAccess = false);
      return;
    }
    final statuses = await [Permission.notification].request();
    final granted = statuses[Permission.notification]?.isGranted == true;
    if (mounted) {
      setState(() => _notifAccess = granted);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(granted ? 'Notification access granted' : 'Permission denied \u2014 you can enable it in system settings')));
      if (!granted && statuses[Permission.notification]?.isPermanentlyDenied == true) {
        final open = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Permission required'), content: const Text('Please enable notification access and SMS in system settings to use Auto-capture.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings'))]));
        if (open == true) await openAppSettings();
      }
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
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Wallet name', hintText: 'e.g. Equity Bank', filled: true, fillColor: AppColors.muted, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              DropdownButtonFormField<WalletType>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: 'Type', filled: true, fillColor: AppColors.muted, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd), borderSide: BorderSide.none)),
                items: WalletType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() => selectedType = v ?? WalletType.cash),
              ),
              const SizedBox(height: 12),
              TextField(controller: balanceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Initial balance (UGX)', hintText: '0', filled: true, fillColor: AppColors.muted, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd), borderSide: BorderSide.none))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final wallet = Wallet(
        id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
        name: nameCtrl.text.trim(),
        type: selectedType,
        color: AppColors.primary.toARGB32(),
        openingBalance: double.tryParse(balanceCtrl.text.replaceAll(',', '')) ?? 0,
        currentBalance: double.tryParse(balanceCtrl.text.replaceAll(',', '')) ?? 0,
      );
      if (!context.mounted) return;
      await context.read<TrackerViewModel>().saveWallet(wallet);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wallet "${wallet.name}" added')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final s = vm.settings;
    final symbol = s.currencySymbol;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: 'Settings', back: false),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallets
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wallets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                          if (vm.wallets.isEmpty)
                            const EmptyState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'No wallets yet',
                              message: 'Add your first wallet to start tracking balances.',
                            )
                          else
                            ...vm.wallets.map((w) => _SettingsRow(
                              icon: w.type.icon,
                              iconColor: w.color != 0 ? Color(w.color) : AppColors.mutedForeground,
                              title: w.name,
                              subtitle: MoneyFormat.money(w.currentBalance, symbol: symbol),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.mutedForeground, size: 18),
                            )),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showAddWalletDialog(context),
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                              child: const Center(child: Text('+ Add wallet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notifications
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                          _ToggleRow(label: 'Budget warnings at 80%', value: _budgetWarnings, onChanged: (v) => setState(() => _budgetWarnings = v)),
                          _ToggleRow(label: 'Bill due reminders', value: _billReminders, onChanged: (v) => setState(() => _billReminders = v)),
                          _ToggleRow(label: 'Unusual spending alerts', value: _unusualSpending, onChanged: (v) => setState(() => _unusualSpending = v)),
                          _ToggleRow(label: 'Weekly money summary', value: _weeklySummary, onChanged: (v) => setState(() => _weeklySummary = v)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notification access
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              const Text('Notification access', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('With permission, MoneyTrack reads the money alerts your phone already receives \u2014 MTN, Airtel and bank messages \u2014 so transactions fill themselves in instead of you typing every one. Alerts are read on your phone only, and nothing is recorded until you confirm it.',
                              style: TextStyle(fontSize: 11, color: AppColors.mutedForeground, height: 1.5)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text(_notifAccess ? 'Allowed' : 'Not allowed', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                              _Toggle(value: _notifAccess, onChanged: _requestNotificationAccess),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/capture'),
                            child: const Text('Review detected transactions \u2192', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dark mode
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                            child: Icon(s.darkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined, color: AppColors.textPrimary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Dark mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Text('Easier on the eyes at night', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                          ])),
                          _Toggle(value: s.darkMode, onChanged: (v) => vm.updateSettings(s..darkMode = v)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Icon library
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Icon library', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Used when you create categories and goals', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 6,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                            children: [
                              for (final i in _iconLibrary.take(24))
                                Container(
                                  decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                                  child: Center(child: _iconForName(i, color: AppColors.mutedForeground)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/categories'),
                            child: const Text('Manage categories \u2192', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _iconLibrary = [
    'ShoppingBag', 'Bus', 'Home', 'Zap', 'Droplets', 'Fuel',
    'Spray', 'Heart', 'Music', 'Coffee', 'Smartphone', 'GraduationCap',
    'Shield', 'Laptop', 'MapPin', 'Plane', 'PiggyBank', 'AttachMoney',
    'Briefcase', 'PawPrint', 'Gamepad2', 'Film', 'PartyPopper', 'Package2',
  ];

  IconData _iconDataForName(String name) {
    switch (name) {
      case 'ShoppingBag': return Icons.shopping_bag_outlined;
      case 'Bus': return Icons.directions_bus_outlined;
      case 'Home': return Icons.home_outlined;
      case 'Zap': return Icons.bolt_outlined;
      case 'Droplets': return Icons.water_drop_outlined;
      case 'Fuel': return Icons.local_gas_station_outlined;
      case 'Spray': return Icons.cleaning_services_outlined;
      case 'Heart': return Icons.favorite_outline;
      case 'Music': return Icons.music_note_outlined;
      case 'Coffee': return Icons.local_cafe_outlined;
      case 'Smartphone': return Icons.smartphone_outlined;
      case 'GraduationCap': return Icons.school_outlined;
      case 'Shield': return Icons.shield_outlined;
      case 'Laptop': return Icons.laptop_outlined;
      case 'MapPin': return Icons.location_on_outlined;
      case 'Plane': return Icons.flight_outlined;
      case 'PiggyBank': return Icons.savings_outlined;
      case 'AttachMoney': return Icons.attach_money_outlined;
      case 'Briefcase': return Icons.work_outlined;
      case 'PawPrint': return Icons.pets_outlined;
      case 'Gamepad2': return Icons.sports_esports_outlined;
      case 'Film': return Icons.movie_outlined;
      case 'PartyPopper': return Icons.celebration_outlined;
      case 'Package2': return Icons.inventory_2_outlined;
      default: return Icons.category_outlined;
    }
  }

  Widget _iconForName(String name, {required Color color}) {
    return Icon(_iconDataForName(name), size: 18, color: color);
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsRow({required this.icon, this.iconColor, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle), child: Icon(icon, size: 16, color: iconColor ?? AppColors.mutedForeground)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          ])),
          ?trailing,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AppColors.primary : AppColors.muted,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2, offset: const Offset(0, 1))])),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          _Toggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}