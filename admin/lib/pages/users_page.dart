import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Everyone with a backup account, most recently active first, searchable
/// by email.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.onOpenUser});

  final ValueChanged<String> onOpenUser;

  static const pageSize = 50;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _usersQuery.snapshots();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _usersQuery {
    final users = AdminServices.of(context).db.collection('users');
    if (_query.isEmpty) return users.orderBy('lastSeenAt', descending: true).limit(UsersPage.pageSize);
    // Prefix match on email (Firestore has no full-text search).
    return users.orderBy('email').startAt([_query]).endAt(['$_query']).limit(UsersPage.pageSize);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim().toLowerCase();
      if (q == _query || !mounted) return;
      setState(() {
        _query = q;
        _stream = _usersQuery.snapshots();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageHeader(title: 'Users', subtitle: 'People who back up their MoneyTrack data with an account'),
        Card(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 360,
                          child: TextField(
                            controller: _search,
                            onChanged: (v) {
                              setState(() {}); // the clear button
                              _onSearch(v);
                            },
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search by email',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () {
                                        _search.clear();
                                        _onSearch('');
                                        setState(() {});
                                      },
                                    ),
                            ),
                          ),
                        ),
                        Text(
                          !snap.hasData
                              ? ''
                              : _query.isEmpty
                                  ? (docs.length == UsersPage.pageSize
                                      ? 'Showing the ${UsersPage.pageSize} most recently active'
                                      : '${formatCount(docs.length)} ${docs.length == 1 ? 'user' : 'users'}')
                                  : '${formatCount(docs.length)} ${docs.length == 1 ? 'match' : 'matches'}',
                          style: const TextStyle(color: AdminColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  if (!narrow)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: _Columns(
                        name: ColumnLabel('User'),
                        phone: ColumnLabel('Phone'),
                        transactions: ColumnLabel('Transactions', align: TextAlign.right),
                        lastSeen: ColumnLabel('Last seen', align: TextAlign.right),
                      ),
                    ),
                  if (!narrow) const Divider(),
                  if (snap.hasError)
                    EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load users', message: '${snap.error}')
                  else if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  else if (docs.isEmpty)
                    EmptyState(
                      icon: Icons.person_search_rounded,
                      title: _query.isEmpty ? 'No users yet' : 'No one matches "$_query"',
                      message: _query.isEmpty
                          ? 'People appear here when they create a backup account in the app.'
                          : 'Search matches the start of an email address.',
                    )
                  else
                    for (final (i, d) in docs.indexed) ...[
                      if (i > 0) const Divider(),
                      _UserRow(data: d.data(), narrow: narrow, onTap: () => widget.onOpenUser(d.id)),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The table's column widths, shared by the header and the rows.
class _Columns extends StatelessWidget {
  const _Columns({
    required this.name,
    required this.phone,
    required this.transactions,
    required this.lastSeen,
    this.trailing = const SizedBox(width: 28),
  });
  final Widget name;
  final Widget phone;
  final Widget transactions;
  final Widget lastSeen;

  /// 28 wide: the row's chevron, or empty in the header.
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(flex: 5, child: name),
          Expanded(flex: 2, child: phone),
          Expanded(flex: 2, child: transactions),
          Expanded(flex: 2, child: lastSeen),
          trailing,
        ],
      );
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.data, required this.narrow, required this.onTap});
  final Map<String, dynamic> data;
  final bool narrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] as String?)?.trim();
    final hasName = name?.isNotEmpty ?? false;
    final email = (data['email'] as String?) ?? '';
    final phone = (data['phone'] as String?)?.trim();
    final transactions = ((data['counts'] as Map<String, dynamic>?)?['transactions'] as num?) ?? 0;
    final who = Row(
      children: [
        InitialsAvatar(name: hasName ? name! : email),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hasName ? name! : 'No name',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: narrow
            ? Row(
                children: [
                  Expanded(child: who),
                  Text(formatAgo(data['lastSeenAt']), style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
                  const Icon(Icons.chevron_right_rounded, color: AdminColors.muted),
                ],
              )
            : _Columns(
                name: who,
                phone: Text((phone?.isNotEmpty ?? false) ? phone! : '-',
                    style: const TextStyle(fontSize: 13, color: AdminColors.text)),
                transactions: Text(formatCount(transactions),
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                lastSeen: Text(formatAgo(data['lastSeenAt']),
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AdminColors.muted)),
                trailing: const SizedBox(
                  width: 28,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right_rounded, color: AdminColors.muted, size: 20),
                  ),
                ),
              ),
      ),
    );
  }
}
