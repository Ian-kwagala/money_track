import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Read-only view of one user's backed-up data, for support.
///
/// Opening it writes an entry to `admin_audit` first, and nothing is shown
/// unless that succeeds, so every look at a user's financial data is
/// recorded. Admins can't edit user data: the Firestore rules only grant
/// them read access under `users/{uid}`.
class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.uid, required this.admin, required this.onBack});

  final String uid;
  final AdminAccount admin;
  final VoidCallback onBack;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Future<void>? _audit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audit ??= AdminServices.of(context).db.collection('admin_audit').add({
      'adminUid': widget.admin.uid,
      'adminEmail': widget.admin.email,
      'action': 'view_user',
      'targetUid': widget.uid,
      'at': FieldValue.serverTimestamp(),
    });
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      AdminServices.of(context).db.collection('users').doc(widget.uid);

  @override
  Widget build(BuildContext context) {
    final back = TextButton.icon(
      onPressed: widget.onBack,
      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AdminColors.muted),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('All users'),
    );
    return FutureBuilder<void>(
      future: _audit,
      builder: (context, audit) {
        if (audit.hasError) {
          return ListView(padding: pagePadding(context), children: [
            PageHeader(title: 'User details', leading: back),
            Notice.error('Your access couldn\'t be logged, so this user\'s data isn\'t shown. (${audit.error})'),
          ]);
        }
        if (audit.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDoc.snapshots(),
          builder: (context, snap) {
            final u = snap.data?.data() ?? const <String, dynamic>{};
            final name = (u['displayName'] as String?)?.trim();
            final email = (u['email'] as String?) ?? '';
            final currency = u['currencyCode'] as String?;
            return ListView(
              padding: pagePadding(context),
              children: [
                PageHeader(
                  leading: back,
                  title: (name?.isNotEmpty ?? false) ? name! : (email.isNotEmpty ? email : 'User details'),
                  subtitle: email.isEmpty ? null : '$email · joined ${formatDate(u['createdAt'])}',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: widget.uid));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('User ID copied')));
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy user ID'),
                    ),
                  ],
                ),
                const Notice.info(
                  'Read-only. This visit was recorded in the audit log. Only open accounts of people you\'re helping.',
                ),
                const SizedBox(height: 20),
                if (!snap.hasData)
                  const LinearProgressIndicator()
                else
                  _Columns(
                    minWidth: 900,
                    children: [
                      _ProfilePanel(data: u, uid: widget.uid),
                      _SummaryPanel(counts: (u['counts'] as Map<String, dynamic>?) ?? const {}),
                    ],
                  ),
                const SizedBox(height: 20),
                _Wallets(userDoc: _userDoc, currency: currency),
                const SizedBox(height: 20),
                _Transactions(userDoc: _userDoc, currency: currency),
                const SizedBox(height: 20),
                _Columns(
                  minWidth: 1100,
                  children: [
                    _Records(
                      title: 'Savings goals',
                      icon: Icons.savings_outlined,
                      query: _userDoc.collection('savings_goals').limit(50),
                      line: (d) => (d['name'] as String?) ?? '',
                      value: (d) => '${formatMoney(d['currentAmount'])} / ${formatMoney(d['targetAmount'], currency)}',
                    ),
                    _Records(
                      title: 'Bills',
                      icon: Icons.receipt_outlined,
                      query: _userDoc.collection('bills').limit(50),
                      line: (d) => '${d['name'] ?? ''} · ${d['frequency'] ?? ''}',
                      value: (d) => formatMoney(d['amount'], currency),
                    ),
                    _Records(
                      title: 'Debts',
                      icon: Icons.handshake_outlined,
                      query: _userDoc.collection('debts').limit(50),
                      line: (d) => '${d['counterparty'] ?? ''} · '
                          '${d['direction'] == 'owedToMe' ? 'owes them' : 'they owe'}'
                          '${d['isSettled'] == true ? ' (settled)' : ''}',
                      value: (d) => formatMoney(d['amount'], currency),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Side by side when there's room, stacked otherwise.
class _Columns extends StatelessWidget {
  const _Columns({required this.children, required this.minWidth});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < minWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 20), c],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: 20), Expanded(child: c)],
          ],
        ),
      );
    });
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.data, required this.uid});
  final Map<String, dynamic> data;
  final String uid;

  @override
  Widget build(BuildContext context) {
    String text(String key) {
      final v = (data[key] as String?)?.trim();
      return (v?.isNotEmpty ?? false) ? v! : '-';
    }

    final rows = <(String, String)>[
      ('Phone', text('phone')),
      ('Occupation', text('occupation')),
      ('Income type', text('incomeType')),
      ('Currency', text('currencyCode')),
      ('Platform', text('platform')),
      ('Last seen', '${formatAgo(data['lastSeenAt'])} (${formatDateTime(data['lastSeenAt'])})'),
      ('User ID', uid),
    ];
    final name = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?) ?? '';
    return Panel(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: (name?.isNotEmpty ?? false) ? name! : email, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((name?.isNotEmpty ?? false) ? name! : 'No name',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(email, style: const TextStyle(color: AdminColors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(label, style: const TextStyle(color: AdminColors.muted, fontSize: 13)),
                  ),
                  Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// How much this person has backed up, from the counts their app reports.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.counts});
  final Map<String, dynamic> counts;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Transactions', 'transactions', Icons.receipt_long_rounded, AdminColors.warning, AdminColors.warningSoft),
      ('Wallets', 'wallets', Icons.account_balance_wallet_rounded, AdminColors.info, AdminColors.infoSoft),
      ('Budgets', 'budgets', Icons.pie_chart_rounded, AdminColors.green, AdminColors.greenSoft),
      ('Savings goals', 'savingsGoals', Icons.savings_rounded, AdminColors.violet, AdminColors.violetSoft),
      ('Bills', 'bills', Icons.receipt_rounded, AdminColors.info, AdminColors.infoSoft),
      ('Debts', 'debts', Icons.handshake_rounded, AdminColors.danger, AdminColors.dangerSoft),
    ];
    Widget tile((String, String, IconData, Color, Color) item) {
      final (label, key, icon, color, soft) = item;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatCount((counts[key] as num?) ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  Text(label,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Two per row. (No LayoutBuilder: this sits in an IntrinsicHeight.)
    return Panel(
      title: 'Backed-up data',
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(children: [
              Expanded(child: tile(items[i])),
              const SizedBox(width: 12),
              Expanded(child: tile(items[i + 1])),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Live (not deleted) records' data from a synced collection.
List<Map<String, dynamic>> _live(QuerySnapshot<Map<String, dynamic>>? snap) => (snap?.docs ?? const [])
    .map((d) => d.data())
    .where((m) => m['deleted'] != true && m['data'] is Map<String, dynamic>)
    .map((m) => m['data'] as Map<String, dynamic>)
    .toList();

class _Wallets extends StatelessWidget {
  const _Wallets({required this.userDoc, required this.currency});
  final DocumentReference<Map<String, dynamic>> userDoc;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: userDoc.collection('wallets').limit(50).snapshots(),
      builder: (context, snap) {
        final wallets = _live(snap.data);
        final total = wallets.fold<num>(0, (acc, w) => acc + ((w['currentBalance'] as num?) ?? 0));
        return Panel(
          title: 'Wallets',
          trailing: wallets.isEmpty
              ? null
              : Text('Total ${formatMoney(total, currency)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          padding: wallets.isEmpty ? null : const EdgeInsets.all(16),
          child: !snap.hasData
              ? const LinearProgressIndicator()
              : wallets.isEmpty
                  ? const Text('No wallets', style: TextStyle(color: AdminColors.muted))
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final w in wallets)
                          Container(
                            width: 220,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AdminColors.field,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((w['name'] as String?) ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(formatMoney(w['currentBalance'], currency),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ],
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}

class _Transactions extends StatelessWidget {
  const _Transactions({required this.userDoc, required this.currency});
  final DocumentReference<Map<String, dynamic>> userDoc;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        userDoc.collection('transactions').orderBy('data.dateTime', descending: true).limit(30).get(),
        userDoc.collection('categories').get(),
      ]),
      builder: (context, snap) {
        final categories = {
          for (final d in snap.data?[1].docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            d.id: ((d.data()['data'] as Map<String, dynamic>?)?['name'] as String?) ?? d.id,
        };
        final txs = _live(snap.data?[0]);
        return Panel(
          title: 'Recent transactions',
          trailing: txs.isEmpty
              ? null
              : Text('Latest ${txs.length}', style: const TextStyle(color: AdminColors.muted, fontSize: 13)),
          padding: EdgeInsets.zero,
          child: !snap.hasData
              ? const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator())
              : txs.isEmpty
                  ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions backed up')
                  : Column(
                      children: [
                        for (final (i, t) in txs.indexed) ...[
                          if (i > 0) const Divider(indent: 20, endIndent: 20),
                          _TransactionRow(tx: t, category: categories[t['categoryId']], currency: currency),
                        ],
                      ],
                    ),
        );
      },
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx, required this.category, required this.currency});
  final Map<String, dynamic> tx;
  final String? category;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final (icon, color, soft, sign) = switch (tx['type']) {
      'income' => (Icons.south_west_rounded, AdminColors.green, AdminColors.greenSoft, '+'),
      'transfer' => (Icons.swap_horiz_rounded, AdminColors.info, AdminColors.infoSoft, ''),
      _ => (Icons.north_east_rounded, AdminColors.danger, AdminColors.dangerSoft, '−'),
    };
    final note = (tx['note'] as String?)?.trim();
    final title = category ?? (tx['type'] == 'transfer' ? 'Transfer' : 'Uncategorised');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (note?.isNotEmpty ?? false)
                  Text(note!, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${formatMoney(tx['amount'], currency)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: tx['type'] == 'income' ? AdminColors.green : AdminColors.text)),
              Text(formatDate(tx['dateTime']), style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small panel listing one kind of record.
class _Records extends StatelessWidget {
  const _Records({required this.title, required this.icon, required this.query, required this.line, required this.value});
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> query;
  final String Function(Map<String, dynamic> data) line;
  final String Function(Map<String, dynamic> data) value;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final items = _live(snap.data);
        return Panel(
          title: snap.hasData ? '$title (${items.length})' : title,
          padding: EdgeInsets.zero,
          child: !snap.hasData
              ? const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator())
              : items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Icon(icon, size: 18, color: AdminColors.muted),
                        const SizedBox(width: 10),
                        Text('None', style: const TextStyle(color: AdminColors.muted)),
                      ]),
                    )
                  : Column(
                      children: [
                        for (final (i, d) in items.indexed) ...[
                          if (i > 0) const Divider(indent: 20, endIndent: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(line(d), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                ),
                                const SizedBox(width: 8),
                                Text(value(d), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
        );
      },
    );
  }
}
