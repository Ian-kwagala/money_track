import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Read-only view of one user's backed-up data, for support.
///
/// Opening it writes an entry to `admin_audit` first, so every look at a
/// user's financial data is recorded. Admins cannot edit user data: the
/// Firestore rules only grant them read access under `users/{uid}`.
class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.uid, required this.admin});
  final String uid;
  final User admin;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late final Future<void> _audit = FirebaseFirestore.instance.collection('admin_audit').add({
    'adminUid': widget.admin.uid,
    'adminEmail': widget.admin.email,
    'action': 'view_user',
    'targetUid': widget.uid,
    'at': FieldValue.serverTimestamp(),
  });

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(widget.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: FutureBuilder<void>(
        future: _audit,
        builder: (context, auditSnap) {
          if (auditSnap.hasError) {
            return Center(child: Text('Access not logged, so not shown: ${auditSnap.error}'));
          }
          if (auditSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _AuditNotice(),
              const SizedBox(height: 16),
              _Profile(doc: _userDoc),
              const SizedBox(height: 24),
              _Records(
                title: 'Wallets',
                query: _userDoc.collection('wallets').limit(50),
                line: (d) => (d['name'] as String?) ?? '',
                trailing: (d) => _money(d['currentBalance']),
              ),
              _Transactions(userDoc: _userDoc),
              _Records(
                title: 'Savings goals',
                query: _userDoc.collection('savings_goals').limit(50),
                line: (d) => (d['name'] as String?) ?? '',
                trailing: (d) => '${_money(d['currentAmount'])} / ${_money(d['targetAmount'])}',
              ),
              _Records(
                title: 'Bills',
                query: _userDoc.collection('bills').limit(50),
                line: (d) => '${d['name'] ?? ''} · ${d['frequency'] ?? ''}',
                trailing: (d) => _money(d['amount']),
              ),
              _Records(
                title: 'Debts',
                query: _userDoc.collection('debts').limit(50),
                line: (d) => '${d['counterparty'] ?? ''} · ${d['direction'] == 'owedToMe' ? 'owes them' : 'they owe'}${d['isSettled'] == true ? ' (settled)' : ''}',
                trailing: (d) => _money(d['amount']),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _money(Object? v) => v is num ? NumberFormat.decimalPattern().format(v) : '-';

class _AuditNotice extends StatelessWidget {
  const _AuditNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: const Row(children: [
        Icon(Icons.shield_outlined),
        SizedBox(width: 8),
        Expanded(child: Text('Read-only. Your access to this user\'s data has been logged. Only open accounts you are helping.')),
      ]),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.doc});
  final DocumentReference<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final u = snap.data!.data() ?? const {};
        String ts(Object? v) => v is Timestamp ? date.format(v.toDate()) : '-';
        final rows = <(String, String)>[
          ('Name', (u['displayName'] as String?) ?? '-'),
          ('Email', (u['email'] as String?) ?? '-'),
          ('Phone', (u['phone'] as String?)?.isNotEmpty == true ? u['phone'] as String : '-'),
          ('Occupation', (u['occupation'] as String?) ?? '-'),
          ('Income type', (u['incomeType'] as String?) ?? '-'),
          ('Currency', (u['currencyCode'] as String?) ?? '-'),
          ('Platform', (u['platform'] as String?) ?? '-'),
          ('Account created', ts(u['createdAt'])),
          ('Last seen', ts(u['lastSeenAt'])),
          ('User ID', doc.id),
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(width: 160, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
                      Expanded(child: SelectableText(value)),
                    ]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A section listing the live (non-deleted) records of one synced collection.
class _Records extends StatelessWidget {
  const _Records({required this.title, required this.query, required this.line, required this.trailing});
  final String title;
  final Query<Map<String, dynamic>> query;
  final String Function(Map<String, dynamic> data) line;
  final String Function(Map<String, dynamic> data) trailing;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final items = (snap.data?.docs ?? const [])
            .map((d) => d.data())
            .where((m) => m['deleted'] != true && m['data'] is Map<String, dynamic>)
            .map((m) => m['data'] as Map<String, dynamic>)
            .toList();
        return _Section(
          title: '$title (${items.length})',
          loading: !snap.hasData,
          children: [
            for (final d in items) ListTile(dense: true, title: Text(line(d)), trailing: Text(trailing(d))),
          ],
        );
      },
    );
  }
}

class _Transactions extends StatelessWidget {
  const _Transactions({required this.userDoc});
  final DocumentReference<Map<String, dynamic>> userDoc;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd();
    return FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        userDoc.collection('transactions').orderBy('data.dateTime', descending: true).limit(30).get(),
        userDoc.collection('categories').get(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const _Section(title: 'Recent transactions', loading: true, children: []);
        final categories = {
          for (final d in snap.data![1].docs) d.id: ((d.data()['data'] as Map<String, dynamic>?)?['name'] as String?) ?? d.id,
        };
        final txs = snap.data![0].docs
            .map((d) => d.data())
            .where((m) => m['deleted'] != true && m['data'] is Map<String, dynamic>)
            .map((m) => m['data'] as Map<String, dynamic>)
            .toList();
        return _Section(
          title: 'Recent transactions (latest ${txs.length})',
          loading: false,
          children: [
            for (final t in txs)
              ListTile(
                dense: true,
                leading: Icon(
                  t['type'] == 'income'
                      ? Icons.south_west
                      : t['type'] == 'transfer'
                          ? Icons.swap_horiz
                          : Icons.north_east,
                  size: 18,
                ),
                title: Text([
                  categories[t['categoryId']] ?? t['type'] ?? '',
                  if ((t['note'] as String?)?.isNotEmpty == true) t['note'],
                ].join(' · ')),
                subtitle: Text(t['dateTime'] is Timestamp ? date.format((t['dateTime'] as Timestamp).toDate()) : ''),
                trailing: Text(_money(t['amount'])),
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.loading, required this.children});
  final String title;
  final bool loading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: loading
                ? const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())
                : children.isEmpty
                    ? const ListTile(dense: true, title: Text('None'))
                    : Column(children: children),
          ),
        ],
      ),
    );
  }
}
