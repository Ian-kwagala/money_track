import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_transaction/quick_add_sheet.dart';
import 'alerts/alerts_screen.dart';
import 'budgets/budgets_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'theme/app_theme.dart';
import '../viewmodels/tracker_view_model.dart';

class HomeShell extends StatefulWidget {
  final int initialIndex;

  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  static const _navItems = [
    _NavInfo(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    _NavInfo(label: 'Budgets', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
    _NavInfo(label: 'Analytics', icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart),
    _NavInfo(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
    _NavInfo(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
      const AlertsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          // Bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_navItems.length, (i) {
                      final item = _navItems[i];
                      final active = _index == i;
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _index = i),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  active ? item.activeIcon : item.icon,
                                  color: active ? AppColors.primary : AppColors.mutedForeground,
                                  size: 22,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                                    color: active ? AppColors.primary : AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          // FAB
          Positioned(
            left: 0,
            right: 0,
            bottom: 88, // 64 nav + 24 gap
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openQuickAdd(context),
                  borderRadius: BorderRadius.circular(28),
                  child: Ink(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.shadowLift,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickAdd(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddSheet(),
    );
  }
}

class _NavInfo {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavInfo({required this.label, required this.icon, required this.activeIcon});
}

/// Shared PageHeader used by all screens
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool back;
  final Widget? action;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.back = true,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final isDark = vm.settings.darkMode;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6), width: 1),
          ),
        ),
        child: Row(
          children: [
            if (back)
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(28),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_left, size: 22, color: AppColors.textPrimary),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            action ??
                InkWell(
                  onTap: () => vm.updateSettings(vm.settings..darkMode = !isDark),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.muted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}