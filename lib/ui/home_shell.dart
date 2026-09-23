import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_transaction/quick_add_sheet.dart';
import 'alerts/alerts_screen.dart';
import 'budgets/budgets_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'dashboard/daily_budget_prompt.dart';
import 'dashboard/payday_check.dart';
import 'dashboard/profile_completion_sheet.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await CompletenessCheck.maybeShow(context);
      if (!mounted) return;
      await DailyBudgetPrompt.maybeShow(context);
      if (!mounted) return;
      await PaydayCheck.maybeShow(context);
    });
  }

  static const _navItems = [
    _NavInfo(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    _NavInfo(label: 'Budgets', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
    _NavInfo(label: 'Analytics', icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart),
    _NavInfo(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
    _NavInfo(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  /// Sidebar sections shown on wide (web/desktop) layouts. Each entry is a
  /// group label followed by the indices (into `_navItems`) it contains.
  static const _sidebarGroups = [
    ('Overview', [0, 2]), // Home, Analytics
    ('Money', [1, 3]), // Budgets, Alerts
    ('Account', [4]), // Settings
  ];

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
      const AlertsScreen(),
      const SettingsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return _buildWide(context, pages);
        }
        return _buildMobile(context, pages);
      },
    );
  }

  Widget _buildWide(BuildContext context, List<Widget> pages) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          _Sidebar(
            groups: _sidebarGroups,
            items: _navItems,
            activeIndex: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, inner) {
                const maxContentWidth = 480.0;
                final contentWidth =
                    inner.maxWidth < maxContentWidth ? inner.maxWidth : maxContentWidth;
                final sideInset = (inner.maxWidth - contentWidth) / 2;
                return Container(
                  color: AppColors.bg,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: pages[_index],
                        ),
                      ),
                      Positioned(
                        right: sideInset < 24 ? 24 : sideInset + 8,
                        bottom: 24,
                        child: _QuickAddFab(onTap: () => _openQuickAdd(context)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, List<Widget> pages) {
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
              child: _QuickAddFab(onTap: () => _openQuickAdd(context)),
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

/// Round green "quick add" button, shared by the mobile and wide layouts.
class _QuickAddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickAddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
    );
  }
}

/// Left navigation sidebar shown on wide (web/desktop) layouts. Groups
/// items under section labels, e.g. "Overview", "Money", "Account".
class _Sidebar extends StatelessWidget {
  final List<(String, List<int>)> groups;
  final List<_NavInfo> items;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.groups,
    required this.items,
    required this.activeIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.elevated,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.savings_outlined, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MoneyTrack',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: Text(
                        group.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    for (final i in group.$2) _SidebarItem(
                      info: items[i],
                      active: activeIndex == i,
                      onTap: () => onSelect(i),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavInfo info;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem({required this.info, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Icon(active ? info.activeIcon : info.icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              info.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
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