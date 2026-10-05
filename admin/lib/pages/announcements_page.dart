import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Messages shown on the home screen of every MoneyTrack install (signed in
/// or not). The app shows the newest active one; users can dismiss it.
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key, required this.admin});
  final User admin;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('announcements');

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New announcement'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Could not load: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No announcements yet'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final ref = docs[i].reference;
              final a = docs[i].data();
              final created = a['createdAt'] is Timestamp ? date.format((a['createdAt'] as Timestamp).toDate()) : 'just now';
              final expires = a['expiresAt'] is Timestamp ? ' · expires ${date.format((a['expiresAt'] as Timestamp).toDate())}' : '';
              return Card(
                child: ListTile(
                  leading: Icon(switch (a['level']) {
                    'warning' => Icons.warning_amber_rounded,
                    'update' => Icons.system_update_alt,
                    _ => Icons.campaign_outlined,
                  }),
                  title: Text((a['title'] as String?) ?? ''),
                  subtitle: Text('${a['body'] ?? ''}\n$created by ${a['createdBy'] ?? '?'}$expires'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: a['active'] == true ? 'Live — tap to hide' : 'Hidden — tap to publish',
                        child: Switch(
                          value: a['active'] == true,
                          onChanged: (v) => ref.update({'active': v}),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete announcement?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) await ref.delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    var level = 'info';
    int? expiresInDays;
    var publishNow = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New announcement'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title'), maxLength: 80),
                TextField(controller: body, decoration: const InputDecoration(labelText: 'Message'), maxLines: 4, maxLength: 400),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'update', child: Text('App update')),
                  ],
                  onChanged: (v) => setState(() => level = v ?? 'info'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: expiresInDays,
                  decoration: const InputDecoration(labelText: 'Expires'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Never')),
                    DropdownMenuItem(value: 1, child: Text('After 1 day')),
                    DropdownMenuItem(value: 7, child: Text('After 7 days')),
                    DropdownMenuItem(value: 30, child: Text('After 30 days')),
                  ],
                  onChanged: (v) => setState(() => expiresInDays = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publish now'),
                  value: publishNow,
                  onChanged: (v) => setState(() => publishNow = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok == true && (title.text.trim().isNotEmpty || body.text.trim().isNotEmpty)) {
      await _col.add({
        'title': title.text.trim(),
        'body': body.text.trim(),
        'level': level,
        'active': publishNow,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': admin.email,
        if (expiresInDays != null)
          'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: expiresInDays!))),
      });
    }
    title.dispose();
    body.dispose();
  }
}
