import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _Stats {
  const _Stats({
    required this.totalUsers,
    required this.active7d,
    required this.active30d,
    required this.new30d,
    required this.totalTransactions,
    required this.activeAnnouncements,
    required this.recentSignups,
  });

  final int totalUsers;
  final int active7d;
  final int active30d;
  final int new30d;
  final int totalTransactions;
  final int activeAnnouncements;
  final List<Map<String, dynamic>> recentSignups;
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late Future<_Stats> _future = _load();

  /// Uses Firestore count/sum aggregations, so user documents aren't
  /// downloaded just to be counted.
  Future<_Stats> _load() async {
    final db = FirebaseFirestore.instance;
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
    final recent = await users.orderBy('createdAt', descending: true).limit(10).get();

    return _Stats(
      totalUsers: results[0].count ?? 0,
      active7d: results[1].count ?? 0,
      active30d: results[2].count ?? 0,
      new30d: results[3].count ?? 0,
      totalTransactions: (results[4].getSum('counts.transactions') ?? 0).round(),
      activeAnnouncements: results[5].count ?? 0,
      recentSignups: recent.docs.map((d) => d.data()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Stats>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load stats: ${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final s = snap.data!;
        final fmt = NumberFormat.decimalPattern();
        final date = DateFormat.yMMMd();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Text('Users who signed in to back up their data', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(label: 'Total users', value: fmt.format(s.totalUsers), icon: Icons.people),
                _StatCard(label: 'Active (7 days)', value: fmt.format(s.active7d), icon: Icons.bolt),
                _StatCard(label: 'Active (30 days)', value: fmt.format(s.active30d), icon: Icons.calendar_month),
                _StatCard(label: 'New (30 days)', value: fmt.format(s.new30d), icon: Icons.person_add_alt),
                _StatCard(label: 'Transactions logged', value: fmt.format(s.totalTransactions), icon: Icons.receipt_long),
                _StatCard(label: 'Live announcements', value: fmt.format(s.activeAnnouncements), icon: Icons.campaign),
              ],
            ),
            const SizedBox(height: 32),
            Text('Recent sign-ups', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (s.recentSignups.isEmpty) const ListTile(title: Text('No users yet')),
                  for (final u in s.recentSignups)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text((u['displayName'] as String?) ?? '(no name)'),
                      subtitle: Text((u['email'] as String?) ?? ''),
                      trailing: Text(u['createdAt'] is Timestamp ? date.format((u['createdAt'] as Timestamp).toDate()) : ''),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(value, style: theme.textTheme.headlineMedium),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
