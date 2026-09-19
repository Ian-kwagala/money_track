import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_shell.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../widgets/empty_state.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../widgets/transaction_tile.dart';
import 'daily_spend_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final spentToday = vm.spentTotal(todayStart, now);
    final spentThisMonth = vm.spentTotal(monthStart, now);
    final incomeThisMonth = vm.incomeTotal(monthStart, now);

    final totalBalance = vm.wallets.fold<double>(
      0,
      (sum, w) => sum + w.currentBalance,
    );
    // Net from all transactions ever (income received - expenses paid)
    final netFromTransactions = vm.transactions.fold<double>(0, (sum, tx) => sum + tx.signedAmount);
    // Show wallet total if wallets have any balance, otherwise show net from transactions
    final displayBalance = totalBalance != 0 ? totalBalance : netFromTransactions;

    final recent = vm.transactions.take(4).toList();

    final totalBudget = vm.budgets.fold<double>(0, (sum, b) => sum + b.amount);
    // Adaptive daily target: prefer budget/month, then income/month, then current pace
    final dailyTarget = totalBudget > 0
        ? totalBudget / 30
        : (incomeThisMonth > 0 ? incomeThisMonth / 30 : (spentThisMonth / now.day));

    // Spending score — based on savings rate + budget compliance
    int score;
    if (vm.transactions.isEmpty && totalBudget == 0) {
      score = 50; // neutral start
    } else {
      final savingsRate = incomeThisMonth > 0
          ? ((incomeThisMonth - spentThisMonth) / incomeThisMonth).clamp(0.0, 1.0)
          : 0.0;
      final budgetCompliance = totalBudget > 0
          ? (1.0 - (spentThisMonth / totalBudget)).clamp(0.0, 1.0)
          : 0.5;
      score = ((savingsRate * 50 + budgetCompliance * 50) + 0.5).round();
      score = score.clamp(0, 100);
    }
    final scoreLabel = score >= 70 ? 'Good' : score >= 40 ? 'Fair' : 'Review spending';
    final scoreColor = score >= 70
        ? AppColors.success
        : score >= 40
            ? AppColors.warning
            : AppColors.danger;

    // Category totals for Top spending
    final categoryTotals = <String, double>{};
    final catColorMap = <String, int>{};
    for (final cat in vm.expenseCategories) {
      final amount = vm.spentByCategory(monthStart, now, cat.id);
      if (amount > 0) {
        categoryTotals[cat.name] = amount;
        catColorMap[cat.name] = cat.color;
      }
    }
    final sortedCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCats.take(3).toList();
    final topTotal = topCats.fold<double>(0, (sum, e) => sum + e.value);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // PageHeader
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Home',
              subtitle: _headerDate(now),
              back: false,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  _BalanceCard(
                    totalBalance: displayBalance,
                    wallets: vm.wallets,
                    symbol: symbol,
                  ),
                  const SizedBox(height: 16),

                  // Income / Spent row
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
                          label: 'Spent this month',
                          amount: spentThisMonth,
                          symbol: symbol,
                          isIncome: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Shortcuts
                  _Shortcuts(),
                  const SizedBox(height: 16),

                  // Top Spending
                  _TopSpending(
                    topCats: topCats,
                    topTotal: topTotal,
                    symbol: symbol,
                    catColorMap: catColorMap,
                  ),
                  const SizedBox(height: 16),

                  // Health Score + Today
                  Row(
                    children: [
                      Expanded(
                        child: _HealthScore(score: score, color: scoreColor, label: scoreLabel),
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
                  const SizedBox(height: 16),

                  // Recent
                  _RecentSection(recent: recent),
                  const SizedBox(height: 16),

                  // Monthly Budget
                  _MonthlyBudgetBar(
                    spent: spentThisMonth,
                    budget: totalBudget,
                    symbol: symbol,
                  ),
                  const SizedBox(height: 100), // FAB clearance
                ],
              ),
            ),
          ),
        ],
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
    final hasBalance = totalBalance != 0;
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
                  hasWallets && hasBalance ? Icons.visibility_outlined : Icons.account_balance_wallet_outlined,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  hasWallets && hasBalance
                      ? 'Total balance \u00b7 ${wallets.length} wallet${wallets.length == 1 ? '' : 's'}'
                      : 'Net balance \u00b7 income - expenses',
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              MoneyFormat.money(totalBalance, symbol: symbol),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (hasWallets && hasBalance) ...[
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
            MoneyFormat.compact(balance, symbol: symbol),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Income/Spent card
class _IncomeSpentCard extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final bool isIncome;

  const _IncomeSpentCard({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.isIncome,
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
            Text(
              MoneyFormat.money(amount, symbol: symbol),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal shortcuts row
class _Shortcuts extends StatelessWidget {
  static const _items = [
    ('Daily spend', Icons.today_outlined, '/daily'),
    ('Bills', Icons.receipt_long_outlined, '/recurring'),
    ('Goals', Icons.flag_outlined, '/goals'),
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

/// Top spending with donut + list
class _TopSpending extends StatelessWidget {
  final List<MapEntry<String, double>> topCats;
  final double topTotal;
  final String symbol;
  final Map<String, int> catColorMap;

  const _TopSpending({
    required this.topCats,
    required this.topTotal,
    required this.symbol,
    required this.catColorMap,
  });

  Color _colorFor(String name, int idx) {
    if (catColorMap.containsKey(name)) return Color(catColorMap[name]!);
    const fallback = [AppColors.catFood, AppColors.catTransport, AppColors.catRent];
    return fallback[idx % 3];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Top spending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/analytics'),
                  child: const Text('Analytics', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (topCats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No expenses recorded this month',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          startDegreeOffset: -90,
                          sections: [
                            for (var i = 0; i < topCats.length; i++)
                              PieChartSectionData(
                                value: topCats[i].value,
                                color: _colorFor(topCats[i].key, i),
                                radius: 20,
                                title: '',
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Top 3', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                          Text(MoneyFormat.compact(topTotal, symbol: symbol),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < topCats.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 7, height: 7, decoration: BoxDecoration(color: _colorFor(topCats[i].key, i), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(topCats[i].key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                              Text(MoneyFormat.compact(topCats[i].value, symbol: symbol),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mutedForeground)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Spending score ring — shows how well user manages expenses
class _HealthScore extends StatelessWidget {
  final int score;
  final Color color;
  final String label;
  const _HealthScore({required this.score, required this.color, required this.label});

  String get _explanation {
    if (score >= 70) return 'You\u2019re saving well and staying within budget.';
    if (score >= 40) return 'Some spending is above target. Review your categories to cut back.';
    return 'Spending exceeds your income or budget. Focus on essentials this month.';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Spending score', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
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
                      value: score / 100,
                      strokeWidth: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _explanation,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, height: 1.3, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today spend ring card
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

/// Recent transactions section
class _RecentSection extends StatelessWidget {
  final List<TxRecord> recent;
  const _RecentSection({required this.recent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Recent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/capture'),
              child: Text(
                recent.isEmpty ? 'See all' : '${recent.length} to review',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message: 'Tap + to add your first expense.',
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

/// Monthly budget progress bar
class _MonthlyBudgetBar extends StatelessWidget {
  final double spent;
  final double budget;
  final String symbol;

  const _MonthlyBudgetBar({required this.spent, required this.budget, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    // Spending bar — always red (expense outflow)
    const color = AppColors.danger;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly budget used', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text('${MoneyFormat.money(spent, symbol: symbol)} of ${MoneyFormat.money(budget, symbol: symbol)}',
                style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}