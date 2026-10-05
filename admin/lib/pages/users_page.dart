import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'user_detail_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.admin});
  final User admin;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _usersQuery {
    final users = FirebaseFirestore.instance.collection('users');
    if (_query.isEmpty) {
      return users.orderBy('lastSeenAt', descending: true).limit(50);
    }
    // Prefix match on email (Firestore has no full-text search).
    return users.orderBy('email').startAt([_query]).endAt(['$_query']).limit(50);
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by email (starts with…)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersQuery.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Could not load users: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No users found'));
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = docs[i].data();
                  final lastSeen = u['lastSeenAt'] is Timestamp ? date.format((u['lastSeenAt'] as Timestamp).toDate()) : 'never';
                  final counts = (u['counts'] as Map<String, dynamic>?) ?? const {};
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text((u['displayName'] as String?)?.isNotEmpty == true ? u['displayName'] as String : '(no name)'),
                    subtitle: Text([
                      u['email'] ?? '',
                      if ((u['phone'] as String?)?.isNotEmpty == true) u['phone'],
                      'last seen $lastSeen',
                    ].join(' · ')),
                    trailing: Text('${counts['transactions'] ?? 0} transactions'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => UserDetailPage(uid: docs[i].id, admin: widget.admin),
                    )),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
