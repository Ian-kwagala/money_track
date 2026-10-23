import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/wallet.dart';
import '../../services/capture/capture_service.dart';
import '../../services/cloud/auth_service.dart';
import '../../services/cloud/connectivity_service.dart';
import '../../services/cloud/sync_service.dart';
import '../../services/shorebird_update_service.dart';
import '../account/account_settings_screen.dart';
import '../account/cloud_account_screen.dart';
import '../auto_capture/turn_on_flow.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../format/money_format.dart';
import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../format/money_input.dart';
import '../widgets/wallet_editor.dart';

/// The Settings tab: a column of cards for backup & sync, wallets, daily
/// budget, alert toggles, SMS auto-capture, dark mode, the icon library,
/// and app updates.
///
/// Most rows save straight away through `vm.updateSettings`; there's no
/// separate Save step.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Edits [AppSettings.dailyBudget]. An empty or zero entry leaves it
  /// unchanged.
  Future<void> _editDailyBudgetDialog(BuildContext context, TrackerViewModel vm) async {
    final ctrl = TextEditingController(text: vm.settings.dailyBudget == null ? '' : MoneyInput.text(vm.settings.dailyBudget!));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily budget'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: MoneyInput.keyboardType,
          inputFormatters: MoneyInput.formatters,
          decoration: InputDecoration(labelText: 'Amount per day (${vm.settings.currencySymbol})', hintText: 'e.g. 20000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', ''));
              Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result <= 0) return;
    final s = vm.settings;
    s.dailyBudget = result;
    await vm.updateSettings(s);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily budget updated')));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final update = context.watch<ShorebirdUpdateService>();
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final online = context.watch<ConnectivityService>().isOnline;
    final s = vm.settings;
    final symbol = s.currencySymbol;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: CustomScrollView(
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
                      // Account & Security (profile details, PIN change, lock app)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppColors.radiusXl),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141E30),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                                    ),
                                    child: const Icon(Icons.person_outline, color: AppColors.primary, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Account & Security', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        Text(
                                          '${vm.currentUser.name} · Profile, PIN & security settings',
                                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.mutedForeground, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cloud backup & sync (optional account). The icon and
                      // subtitle summarise the state; tap for CloudAccountScreen.
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppColors.radiusXl),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudAccountScreen())),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141E30),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                                    ),
                                    child: Icon(
                                      !auth.isAvailable
                                          ? Icons.cloud_off_outlined
                                          : auth.isSignedIn
                                              ? (online ? Icons.cloud_done_outlined : Icons.cloud_queue_outlined)
                                              : Icons.cloud_upload_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Backup & sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        Text(
                                          !auth.isAvailable
                                              ? 'Not set up in this build \u2014 data stays on this phone'
                                              : sync.status == SyncStatus.needsAccountChoice
                                                  ? 'Action needed: account mismatch'
                                                  : !auth.isSignedIn
                                                      ? 'Optional \u2014 sign in to back up your data'
                                                      : !online
                                                          ? 'Offline \u2014 ${sync.pendingCount} change(s) waiting'
                                                          : 'Signed in as ${auth.email ?? ''}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.mutedForeground, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Wallets, each with its balance; tap one to edit or delete
                      // it (showWalletEditor).
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
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
                                  subtitle: MoneyFormat.signed(w.currentBalance, symbol: symbol),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.mutedForeground, size: 18),
                                  onTap: () => showWalletEditor(context, wallet: w),
                                )),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF18263E), Color(0xFF0F172A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => showWalletEditor(context),
                                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: Text(
                                          '+ Add wallet',
                                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Daily budget
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppColors.radiusXl),
                            onTap: () => _editDailyBudgetDialog(context, vm),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141E30),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                                    ),
                                    child: const Icon(Icons.today_outlined, color: AppColors.textPrimary, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Daily budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        Text(
                                          s.dailyBudget == null ? 'Not set' : '${MoneyFormat.money(s.dailyBudget!, symbol: s.currencySymbol)} per day',
                                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedForeground),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notifications: which alerts AlertsService builds.
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const SizedBox(height: 12),
                              _ToggleRow(label: 'Budget warnings at 80%', value: vm.settings.budgetWarningsEnabled, onChanged: (v) => vm.updateSettings(vm.settings..budgetWarningsEnabled = v)),
                              _ToggleRow(label: 'Bill due reminders', value: vm.settings.billRemindersEnabled, onChanged: (v) => vm.updateSettings(vm.settings..billRemindersEnabled = v)),
                              _ToggleRow(label: 'Unusual spending alerts', value: vm.settings.unusualSpendingEnabled, onChanged: (v) => vm.updateSettings(vm.settings..unusualSpendingEnabled = v)),
                              _ToggleRow(label: 'Weekly money summary', value: vm.settings.weeklySummaryEnabled, onChanged: (v) => vm.updateSettings(vm.settings..weeklySummaryEnabled = v)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Auto-capture. The Builder limits rebuilds on capture
                      // changes to this card. It shows as off while permission is
                      // missing, even if the user turned it on.
                      Builder(builder: (context) {
                        final capture = context.watch<CaptureService>();
                        final on = capture.isOn && !capture.needsPermission;
                        final n = capture.pendingCount;
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusXl),
                            side: const BorderSide(color: AppColors.borderLight, width: 1),
                          ),
                          child: Container(
                            decoration: AppColors.cardDecoration(),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.sms_outlined, color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Flexible(child: Text('Auto-capture from SMS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  capture.isSupported
                                      ? 'MoneyTrack reads the money SMS your phone already receives \u2014 MTN, Airtel and bank messages \u2014 so transactions fill themselves in. Messages are read on this phone only, and nothing is recorded until you confirm it.'
                                      : 'Reading SMS only works on Android. You can still paste a money SMS on the Auto-capture screen.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, height: 1.5),
                                ),
                                if (capture.isSupported) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          capture.needsPermission ? 'SMS permission is off' : (on ? 'On' : 'Off'),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      _Toggle(value: on, onChanged: (v) => v ? turnOnAutoCapture(context) : capture.turnOff()),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => Navigator.pushNamed(context, '/capture'),
                                  child: Text(n == 0 ? 'Open auto-capture \u2192' : 'Review $n detected transaction${n == 1 ? '' : 's'} \u2192', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      // Dark mode
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141E30),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                                ),
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

                      // Icon library: a display-only preview of the category
                      // manager's icons, with a link to that screen.
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
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
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF141E30),
                                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                                      ),
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
                      const SizedBox(height: 12),

                      // Software updates (Shorebird code push): installed patch,
                      // a restart hint once a new patch is downloaded, and a
                      // manual check.
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusXl),
                          side: const BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                        child: Container(
                          decoration: AppColors.cardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.system_update_alt_outlined, color: AppColors.primary, size: 18),
                                  SizedBox(width: 8),
                                  Text('Software updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                !update.isAvailable
                                    ? 'Not available in this build.'
                                    : update.currentPatch != null
                                        ? 'Patch ${update.currentPatch!.number} installed'
                                        : 'Base release — no patches installed yet',
                                style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                              ),
                              if (update.state == ShorebirdUpdateState.restartRequired) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                                  child: const Text('An update has been downloaded. Close and reopen MoneyTrack to apply it.', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                ),
                              ],
                              if (update.state == ShorebirdUpdateState.error && update.errorMessage != null) ...[
                                const SizedBox(height: 10),
                                Text("Couldn't check for updates: ${update.errorMessage}", style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                              ],
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF18263E), Color(0xFF0F172A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: (!update.isAvailable || update.isBusy) ? null : () => update.checkForUpdate(),
                                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: update.isBusy
                                            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                            : Text(
                                                'Check for updates',
                                                style: TextStyle(
                                                  color: update.isAvailable ? AppColors.primary : AppColors.mutedForeground,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
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
        ),
      ),
    );
  }

  /// The first 24 of the category manager's icon keys; [Category.materialIcon]
  /// draws them.
  static const _iconLibrary = [
    'ShoppingBag', 'Bus', 'Home', 'Zap', 'Droplets', 'Fuel',
    'Spray', 'Heart', 'Music', 'Coffee', 'Smartphone', 'GraduationCap',
    'Shield', 'Laptop', 'MapPin', 'Plane', 'PiggyBank', 'AttachMoney',
    'Briefcase', 'PawPrint', 'Gamepad2', 'Film', 'PartyPopper', 'Package2',
  ];

  IconData _iconDataForName(String name) => Category.materialIcon(name);

  Widget _iconForName(String name, {required Color color}) {
    return Icon(_iconDataForName(name), size: 18, color: color);
  }
}

/// Icon, title, optional subtitle and trailing widget, tappable as a whole.
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({required this.icon, this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF141E30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: Icon(icon, size: 16, color: iconColor ?? AppColors.mutedForeground),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            ])),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A small custom on/off switch in the app's colours.
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
          color: value ? AppColors.primary : const Color(0xFF141E30),
          border: Border.all(color: value ? AppColors.primary : AppColors.borderLight, width: 1),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A label with a [_Toggle] on the right.
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
