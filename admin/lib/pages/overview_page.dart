import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class _Stats {
  const _Stats({
    required this.totalUsers,
    required this.active7d,
    required this.active30d,
    required this.new30d,
    required this.totalTransactions,
    required this.activeAnnouncements,
    required this.recentSignups,
    required this.loadedAt,
  });

  final int totalUsers;
  final int active7d;
  final int active30d;
  final int new30d;
  final int totalTransactions;
  final int activeAnnouncements;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> recentSignups;
  final DateTime loadedAt;
}

/// Headline numbers, how active people are, and the newest accounts.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.onOpenUser, required this.onSeeAllUsers});

  final ValueChanged<String> onOpenUser;
  final VoidCallback onSeeAllUsers;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Future<_Stats>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  /// Uses Firestore count/sum aggregations, so user documents aren't
  /// downloaded just to be counted.
  Future<_Stats> _load() async {
    final db = AdminServices.of(context).db;
    final users = db.collection('users');
    final now = DateTime.now();
    Timestamp daysAgo(int d) => Timestamp.fromDate(now.subtract(Duration(days: d)));

    final results = await Future.wait([
      users.count().get(),
      users.where('lastSeenAt', isGreaterThanOrEqualTo: daysAgo(7)).count().get(),
      users.where('lastSeenAt', isGreaterThanOrEqualTo: daysAgo(30)).count().get(),
      users.where('createdAt', isGreaterThanOrEqualTo: daysAgo(30)).count().get(),
      users.aggregate(sum('counts.transactions')).get(),
      db.collection('announcements').where('active', isEqualTo: true).count().get(),
    ]);
    final recent = await users.orderBy('createdAt', descending: true).limit(6).get();

    return _Stats(
      totalUsers: results[0].count ?? 0,
      active7d: results[1].count ?? 0,
      active30d: results[2].count ?? 0,
      new30d: results[3].count ?? 0,
      totalTransactions: (results[4].getSum('counts.transactions') ?? 0).round(),
      activeAnnouncements: results[5].count ?? 0,
      recentSignups: recent.docs,
      loadedAt: now,
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Stats>(
      future: _future,
      builder: (context, snap) {
        final s = snap.data;
        return ListView(
          padding: pagePadding(context),
          children: [
            PageHeader(
              title: 'Overview',
              subtitle: s == null
                  ? 'How MoneyTrack is doing'
                  : 'How MoneyTrack is doing · updated ${DateFormat.jm().format(s.loadedAt)}',
              actions: [
                OutlinedButton.icon(
                  onPressed: snap.connectionState == ConnectionState.waiting ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            if (snap.hasError)
              Card(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Couldn\'t load the numbers',
                  message: '${snap.error}',
                  action: FilledButton(onPressed: _refresh, child: const Text('Try again')),
                ),
              )
            else if (s == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _KpiGrid(stats: s),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, box) {
                final engagement = _Engagement(stats: s);
                final recent = _RecentSignups(
                  docs: s.recentSignups,
                  onOpenUser: widget.onOpenUser,
                  onSeeAll: widget.onSeeAllUsers,
                );
                if (box.maxWidth < 900) {
                  return Column(children: [engagement, const SizedBox(height: 24), recent]);
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: engagement),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: recent),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.caption, this.icon, this.color, this.soft);
  final String label;
  final int value;
  final String caption;
  final IconData icon;
  final Color color;
  final Color soft;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final kpis = [
      _Kpi('Total users', s.totalUsers, 'With a backup account', Icons.group_rounded, AdminColors.info, AdminColors.infoSoft),
      _Kpi('Active this week', s.active7d, 'Opened the app in 7 days', Icons.bolt_rounded, AdminColors.green,
          AdminColors.greenSoft),
      _Kpi('New this month', s.new30d, 'Signed up in 30 days', Icons.person_add_alt_1_rounded, AdminColors.violet,
          AdminColors.violetSoft),
      _Kpi('Transactions logged', s.totalTransactions, 'Across all backed-up users', Icons.receipt_long_rounded,
          AdminColors.warning, AdminColors.warningSoft),
      _Kpi('Active this month', s.active30d, 'Opened the app in 30 days', Icons.calendar_month_rounded,
          AdminColors.green, AdminColors.greenSoft),
      _Kpi('Live announcements', s.activeAnnouncements, 'Showing in the app now', Icons.campaign_rounded,
          AdminColors.info, AdminColors.infoSoft),
    ];
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 900 ? 3 : 2;
      const gap = 16.0;
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final k in kpis) SizedBox(width: width, child: _KpiCard(kpi: k, compact: width < 260))],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, this.compact = false});
  final _Kpi kpi;

  /// Two to a row on phones: icon above the number, no caption.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final badge = Container(
      width: compact ? 34 : 44,
      height: compact ? 34 : 44,
      decoration: BoxDecoration(color: kpi.soft, borderRadius: BorderRadius.circular(compact ? 10 : 12)),
      child: Icon(kpi.icon, color: kpi.color, size: compact ? 18 : 22),
    );
    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge,
              const SizedBox(height: 12),
              Text(formatCount(kpi.value),
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6)),
              Text(kpi.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AdminColors.muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kpi.label, style: text.bodyMedium?.copyWith(color: AdminColors.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(formatCount(kpi.value),
                      style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                  const SizedBox(height: 4),
                  Text(kpi.caption, style: text.bodySmall?.copyWith(color: AdminColors.muted)),
                ],
              ),
            ),
            badge,
          ],
        ),
      ),
    );
  }
}

/// Share of users active this week and this month.
class _Engagement extends StatelessWidget {
  const _Engagement({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.totalUsers;
    Widget bar(String label, int value, Color color) {
      final share = total == 0 ? 0.0 : value / total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Text('${formatCount(value)} of ${formatCount(total)}',
                  style: const TextStyle(color: AdminColors.muted, fontSize: 13)),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text('${(share * 100).round()}%',
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              color: color,
              backgroundColor: AdminColors.canvas,
            ),
          ),
        ],
      );
    }

    return Panel(
      title: 'Engagement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar('Active this week', stats.active7d, AdminColors.green),
          const SizedBox(height: 22),
          bar('Active this month', stats.active30d, AdminColors.info),
          const SizedBox(height: 22),
          bar('Joined this month', stats.new30d, AdminColors.violet),
          const SizedBox(height: 20),
          const Text(
            'Counts people who signed in to back up their data. People using MoneyTrack '
            'without an account aren\'t included.',
            style: TextStyle(color: AdminColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RecentSignups extends StatelessWidget {
  const _RecentSignups({required this.docs, required this.onOpenUser, required this.onSeeAll});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final ValueChanged<String> onOpenUser;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Recent sign-ups',
      trailing: TextButton(onPressed: onSeeAll, child: const Text('All users')),
      padding: EdgeInsets.zero,
      child: docs.isEmpty
          ? const EmptyState(
              icon: Icons.person_add_alt_rounded,
              title: 'No sign-ups yet',
              message: 'People appear here when they create a backup account in the app.',
            )
          : Column(
              children: [
                for (final (i, d) in docs.indexed) ...[
                  if (i > 0) const Divider(indent: 20, endIndent: 20),
                  _PersonRow(data: d.data(), onTap: () => onOpenUser(d.id)),
                ],
              ],
            ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.data, required this.onTap});
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?) ?? '';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(name: (name?.isNotEmpty ?? false) ? name! : email),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((name?.isNotEmpty ?? false) ? name! : 'No name',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              MediaQuery.sizeOf(context).width < 640
                  ? formatAgo(data['createdAt'])
                  : 'Joined ${formatDate(data['createdAt'])}',
              style: const TextStyle(color: AdminColors.muted, fontSize: 12),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AdminColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
