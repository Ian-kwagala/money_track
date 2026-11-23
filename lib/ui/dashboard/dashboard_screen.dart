import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../account/cloud_account_screen.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../home_shell.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import '../../services/cloud/sync_service.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../widgets/alerts_bell.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/capture_review_banner.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton/skeleton_loading.dart';
import '../../models/bill.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../widgets/transaction_tile.dart';
import 'category_expense_pie_chart.dart';
import 'daily_spend_screen.dart';
import 'monthly_budget_card.dart';

/// The Home tab: the at-a-glance summary of the user's money.
///
/// From top to bottom: announcement and SMS-review banners, total balance
/// with a pill per wallet, this month's income and total expenses, shortcut
/// chips to the secondary screens, bills due within a week, an interactive
/// expense-by-category pie chart, saved-this-month / average daily spend
/// beside today's spending ring, a searchable recent-transactions list, and
/// the monthly spending limit & remaining-budget card.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Reads [SyncService] if mounted in the widget tree, returning null in
  /// isolated tests that only provide [TrackerViewModel].
  SyncService? _maybeSync(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<SyncService>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// "Tuesday, 13 Oct" for the header subtitle.
  String _headerDate(DateTime now) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final wd = weekdays[now.weekday - 1];
    final m = months[now.month - 1];
    return '$wd, ${now.day} $m';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final sync = _maybeSync(context);

    // When the dashboard is loading initial data or refreshing,
    // show the animated skeleton view to keep the user engaged.
    if (vm.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          top: false,
          child: DashboardSkeleton(),
        ),
      );
    }

    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final spentToday = vm.spentTotal(todayStart, now);
    final spentThisMonth = vm.spentTotal(monthStart, now);
    final incomeThisMonth = vm.incomeTotal(monthStart, now);
    final totalExpensesAllTime = vm.transactions
        .where((t) => t.type == TxType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenseCountThisMonth = vm.transactions
        .where((t) =>
            t.type == TxType.expense &&
            !t.dateTime.isBefore(monthStart) &&
            !t.dateTime.isAfter(now))
        .length;

    final totalBalance = vm.wallets.fold<double>(
      0,
      (sum, w) => sum + w.currentBalance,
    );
    // Net from all transactions ever (income received - expenses paid)
    final netFromTransactions = vm.transactions.fold<double>(0, (sum, tx) => sum + tx.signedAmount);
    // Wallet balances already include every transaction on top of the opening
    // balance, so they're the source of truth. Only fall back to the raw
    // income - expense net when there are no wallets at all (a zero total is
    // a real balance, not a reason to switch to a number that ignores
    // opening balances).
    final displayBalance = vm.wallets.isNotEmpty ? totalBalance : netFromTransactions;

    final isSearching = _searchQuery.trim().isNotEmpty;
    final recent = isSearching
        ? vm.searchTransactions(_searchQuery).take(10).toList()
        : vm.transactions.take(4).toList();

    final monthlyLimit = vm.effectiveMonthlyLimit;
    final dailyTarget = vm.dailyTarget;

    // "Saved" here is simply income minus spending this month (it can go
    // negative). The daily average divides by days elapsed, today included.
    final savedThisMonth = incomeThisMonth - spentThisMonth;
    final avgDailySpend = spentThisMonth / now.day;

    // Full breakdown of this month's expenses by category for the pie chart.
    final categorySlices = <CategoryExpenseSlice>[];
    for (final cat in vm.expenseCategories) {
      final amount = vm.spentByCategory(monthStart, now, cat.id);
      if (amount > 0) {
        categorySlices.add(CategoryExpenseSlice(
          name: cat.name,
          amount: amount,
          color: Color(cat.color),
        ));
      }
    }

    // Bills due within a week (or already overdue), soonest first.
    final upcomingBills = vm.bills.where((b) => b.isDueWithin(7)).toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            final syncRef = _maybeSync(context, listen: false);
            await vm.refreshData();
            if (syncRef != null && syncRef.isEnabled) {
              await syncRef.syncNow();
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
          // PageHeader
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Home',
              subtitle: _headerDate(now),
              back: false,
              extraActions: const [AlertsBell()],
            ),
          ),
          const SliverToBoxAdapter(child: AnnouncementBanner()),
          const SliverToBoxAdapter(child: CaptureReviewBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sync != null && sync.isEnabled) ...[
                    _CloudSyncPill(sync: sync),
                    const SizedBox(height: 12),
                  ],

                  // Balance Card
                  _BalanceCard(
                    totalBalance: displayBalance,
                    wallets: vm.wallets,
                    symbol: symbol,
                  ),
                  const SizedBox(height: 16),

                  // Income / Total expenses summary row
                  Row(
                    children: [
                      Expanded(
                        child: _IncomeSpentCard(
                          label: 'Income this month',
                          amount: incomeThisMonth,
                          symbol: symbol,
                          isIncome: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _IncomeSpentCard(
                          label: 'Total expenses',
                          amount: spentThisMonth,
                          symbol: symbol,
                          isIncome: false,
                          footnote:
                              '$expenseCountThisMonth this month · All: ${MoneyFormat.compact(totalExpensesAllTime, symbol: symbol)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Shortcuts
                  _Shortcuts(),
                  const SizedBox(height: 16),

                  // Upcoming bills
                  if (upcomingBills.isNotEmpty) ...[
                    _UpcomingBills(bills: upcomingBills, symbol: symbol),
                    const SizedBox(height: 16),
                  ],

                  // Expenses by category pie chart
                  CategoryExpensePieChart(
                    slices: categorySlices,
                    symbol: symbol,
                    onAnalyticsTap: () => Navigator.pushNamed(context, '/analytics'),
                  ),
                  const SizedBox(height: 16),

                  // Saved this month + average daily spend, beside Today
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Saved this month',
                                  value: MoneyFormat.signed(savedThisMonth, symbol: symbol),
                                  color: savedThisMonth >= 0 ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _StatCard(
                                  label: 'Avg daily spend',
                                  value: MoneyFormat.money(avgDailySpend.roundToDouble(), symbol: symbol),
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TodaySpendCard(
                            spent: spentToday,
                            budget: dailyTarget,
                            symbol: symbol,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DailySpendScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent transactions with search bar
                  _RecentSection(
                    recent: recent,
                    hasTransactions: vm.transactions.isNotEmpty,
                    searchController: _searchCtrl,
                    searchQuery: _searchQuery,
                    onSearchChanged: (value) => setState(() => _searchQuery = value),
                    onClearSearch: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    onAddTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Monthly spending limit & remaining budget
                  MonthlyBudgetCard(
                    spent: spentThisMonth,
                    limit: monthlyLimit,
                    hasCustomLimit: vm.hasCustomMonthlyLimit,
                    symbol: symbol,
                    onSaveLimit: (limit) => vm.setMonthlySpendingLimit(limit),
                  ),
                  const SizedBox(height: 100), // FAB clearance
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
}

/// Balance card with 2x2 wallet grid
class _BalanceCard extends StatelessWidget {
  final double totalBalance;
  final List<Wallet> wallets;
  final String symbol;

  const _BalanceCard({
    required this.totalBalance,
    required this.wallets,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final hasWallets = wallets.isNotEmpty;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasWallets ? Icons.visibility_outlined : Icons.account_balance_wallet_outlined,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  hasWallets
                      ? 'Total balance \u00b7 ${wallets.length} wallet${wallets.length == 1 ? '' : 's'}'
                      : 'Net balance \u00b7 income - expenses',
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              MoneyFormat.signed(totalBalance, symbol: symbol),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (hasWallets) ...[
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: [
                  for (final w in wallets)
                    _WalletPill(name: w.name, balance: w.currentBalance, symbol: symbol),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One wallet's name and short-form balance inside the balance card.
class _WalletPill extends StatelessWidget {
  final String name;
  final double balance;
  final String symbol;

  const _WalletPill({required this.name, required this.balance, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
          const SizedBox(height: 2),
          Text(
            MoneyFormat.compactSigned(balance, symbol: symbol),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Compact Firestore sync status pill shown when cloud sync is enabled.
class _CloudSyncPill extends StatelessWidget {
  final SyncService sync;

  const _CloudSyncPill({required this.sync});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (sync.status) {
      SyncStatus.synced => ('Cloud sync · Up to date', Icons.cloud_done_outlined, AppColors.primary),
      SyncStatus.syncing => ('Cloud sync · Syncing...', Icons.cloud_sync_outlined, AppColors.info),
      SyncStatus.offline => ('Cloud sync · Offline (${sync.pendingCount} queued)', Icons.cloud_off_outlined, AppColors.warning),
      SyncStatus.error => ('Cloud sync · Needs attention', Icons.cloud_off_outlined, AppColors.danger),
      SyncStatus.needsAccountChoice => ('Cloud sync · Account switch pending', Icons.manage_accounts_outlined, AppColors.warning),
      SyncStatus.signedOut => ('Cloud sync · Sign in to back up to Firestore', Icons.cloud_upload_outlined, AppColors.mutedForeground),
      SyncStatus.disabled => ('Local storage only', Icons.storage_outlined, AppColors.mutedForeground),
    };

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CloudAccountScreen()),
      ),
      borderRadius: BorderRadius.circular(AppColors.radius2xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppColors.radius2xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Income/Spent summary card
class _IncomeSpentCard extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final bool isIncome;
  final String? footnote;

  const _IncomeSpentCard({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.isIncome,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.success : AppColors.danger;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyFormat.money(amount, symbol: symbol),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 4),
              Text(
                footnote!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal shortcuts row
///
/// Chips that open the secondary screens by their named routes in main.dart.
class _Shortcuts extends StatelessWidget {
  /// (label, icon, route name)
  static const _items = [
    ('Transactions', Icons.receipt_outlined, '/transactions'),
    ('Daily spend', Icons.today_outlined, '/daily'),
    ('Bills', Icons.receipt_long_outlined, '/recurring'),
    ('Goals', Icons.flag_outlined, '/goals'),
    ('Debts', Icons.handshake_outlined, '/debts'),
    ('Categories', Icons.category_outlined, '/categories'),
    ('Auto-capture', Icons.sms_outlined, '/capture'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            InkWell(
              onTap: () => Navigator.pushNamed(context, _items[i].$3),
              borderRadius: BorderRadius.circular(AppColors.radius2xl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppColors.radius2xl),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_items[i].$2, size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      _items[i].$1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != _items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Compact list of bills due within the next week (or already overdue).
class _UpcomingBills extends StatelessWidget {
  final List<Bill> bills;
  final String symbol;

  const _UpcomingBills({required this.bills, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        onTap: () => Navigator.pushNamed(context, '/recurring'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Upcoming bills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedForeground),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < bills.length; i++) ...[
                _UpcomingBillRow(bill: bills[i], symbol: symbol),
                if (i != bills.length - 1) const Divider(height: 16, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One bill with its due status (red overdue, amber within 3 days).
class _UpcomingBillRow extends StatelessWidget {
  final Bill bill;
  final String symbol;

  const _UpcomingBillRow({required this.bill, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final overdue = bill.isOverdue;
    final days = bill.daysUntilDue;
    final color = overdue ? AppColors.danger : (days <= 3 ? AppColors.warning : AppColors.primary);
    final label = overdue
        ? 'Overdue by ${-days} day${-days == 1 ? '' : 's'}'
        : days == 0
            ? 'Due today'
            : 'Due in $days day${days == 1 ? '' : 's'}';

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(overdue ? Icons.error_outline : Icons.event_outlined, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bill.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
        Text(MoneyFormat.money(bill.amount, symbol: symbol), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}

/// One figure with a label, e.g. "Saved this month".
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today spend ring card
///
/// Today's spending against [budget] (the daily target). Tap for the daily
/// spend screen.
class _TodaySpendCard extends StatelessWidget {
  final double spent;
  final double budget;
  final String symbol;
  final VoidCallback? onTap;

  const _TodaySpendCard({required this.spent, required this.budget, required this.symbol, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    // Spending ring — always red (expense outflow)
    const color = AppColors.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusXl),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
              const SizedBox(height: 12),
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 8,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(MoneyFormat.compact(spent, symbol: symbol),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text('of ${MoneyFormat.compact(budget, symbol: symbol)}',
                            style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recent transactions section with an inline search bar filtering by title,
/// category, or note.
class _RecentSection extends StatelessWidget {
  final List<TxRecord> recent;
  final bool hasTransactions;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onAddTap;

  const _RecentSection({
    required this.recent,
    required this.hasTransactions,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSearching = searchQuery.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent transactions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const Spacer(),
            TextButton.icon(
              key: const Key('dashboard_add_transaction_button'),
              onPressed: onAddTap,
              icon: const Icon(Icons.add_circle_outline, size: 15),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/transactions'),
              child: const Text(
                'See all',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasTransactions) ...[
          TextField(
            key: const Key('dashboard_search_bar'),
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by title, category, or note...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.mutedForeground),
              suffixIcon: isSearching
                  ? IconButton(
                      key: const Key('dashboard_search_clear'),
                      icon: const Icon(Icons.close, size: 18, color: AppColors.mutedForeground),
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.card,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!hasTransactions)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message: 'Tap + to add your first expense.',
          )
        else if (recent.isEmpty && isSearching)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 28, color: AppColors.mutedForeground),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions matching "$searchQuery"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onClearSearch,
                      child: const Text('Clear search'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final tx in recent) TransactionTile(tx: tx),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
