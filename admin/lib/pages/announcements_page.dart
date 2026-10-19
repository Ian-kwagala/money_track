import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// How each announcement level looks, matching the app's home-screen banner.
(String, IconData, Color) _levelStyle(Object? level) => switch (level) {
      'warning' => ('Warning', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
      'update' => ('App update', Icons.system_update_alt_outlined, const Color(0xFF3B82F6)),
      _ => ('Info', Icons.campaign_outlined, AdminColors.green),
    };

/// Messages shown on the home screen of every MoneyTrack install (signed in
/// or not). The app shows the newest live one; people can dismiss it.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, required this.admin});
  final AdminAccount admin;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  CollectionReference<Map<String, dynamic>> get _col => AdminServices.of(context).db.collection('announcements');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _col.orderBy('createdAt', descending: true).limit(100).snapshots();
  }

  Future<void> _create() async {
    final draft = await showDialog<_Draft>(context: context, builder: (_) => const _NewAnnouncementDialog());
    if (draft == null || !mounted) return;
    await _col.add({
      'title': draft.title,
      'body': draft.body,
      'level': draft.level,
      'active': draft.publishNow,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': widget.admin.email,
      if (draft.expiresInDays != null)
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: draft.expiresInDays!))),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(draft.publishNow ? 'Published. It shows in the app now.' : 'Saved as hidden.'),
      ));
    }
  }

  Future<void> _delete(DocumentReference<Map<String, dynamic>> ref, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text('"$title" will be removed from every phone. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    final newButton = FilledButton.icon(
      onPressed: _create,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text('New announcement'),
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final live = docs.where((d) => _isLive(d.data())).length;
        return ListView(
          padding: pagePadding(context),
          children: [
            PageHeader(
              title: 'Announcements',
              subtitle: snap.hasData
                  ? 'Shown on the home screen of every MoneyTrack app · $live live'
                  : 'Shown on the home screen of every MoneyTrack app',
              actions: [newButton],
            ),
            if (snap.hasError)
              Card(child: EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load', message: '${snap.error}'))
            else if (!snap.hasData)
              const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
            else if (docs.isEmpty)
              Card(
                child: EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  message: 'Tell everyone about a new feature, a problem you\'re fixing, or an update to install.',
                  action: newButton,
                ),
              )
            else
              for (final d in docs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnnouncementCard(
                    data: d.data(),
                    onToggle: (v) => d.reference.update({'active': v}),
                    onDelete: () => _delete(d.reference, (d.data()['title'] as String?) ?? ''),
                  ),
                ),
          ],
        );
      },
    );
  }
}

bool _isExpired(Map<String, dynamic> a) => asDate(a['expiresAt'])?.isBefore(DateTime.now()) ?? false;
bool _isLive(Map<String, dynamic> a) => a['active'] == true && !_isExpired(a);

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.data, required this.onToggle, required this.onDelete});
  final Map<String, dynamic> data;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (levelLabel, icon, color) = _levelStyle(data['level']);
    final title = (data['title'] as String?) ?? '';
    final body = (data['body'] as String?) ?? '';
    final active = data['active'] == true;
    final expired = _isExpired(data);
    final status = expired
        ? const Pill(label: 'Expired', color: AdminColors.danger, background: AdminColors.dangerSoft)
        : active
            ? const Pill(label: 'Live', icon: Icons.circle, color: AdminColors.green, background: AdminColors.greenSoft)
            : const Pill.neutral(label: 'Hidden');
    final meta = [
      data['createdAt'] == null ? 'Just now' : formatDateTime(data['createdAt']),
      if (data['createdBy'] != null) 'by ${data['createdBy']}',
      if (data['expiresAt'] != null) '${expired ? 'expired' : 'expires'} ${formatDate(data['expiresAt'])}',
    ].join(' · ');

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(title.isEmpty ? '(no title)' : title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              status,
                              Pill(label: levelLabel, color: color, background: color.withValues(alpha: 0.12)),
                            ],
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
                          ],
                          const SizedBox(height: 8),
                          Text(meta, style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Tooltip(
                          message: active ? 'Live: turn off to hide it' : 'Hidden: turn on to publish',
                          child: Switch(value: active, onChanged: expired ? null : onToggle),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.muted),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Draft {
  const _Draft(this.title, this.body, this.level, this.expiresInDays, this.publishNow);
  final String title;
  final String body;
  final String level;
  final int? expiresInDays;
  final bool publishNow;
}

class _NewAnnouncementDialog extends StatefulWidget {
  const _NewAnnouncementDialog();

  @override
  State<_NewAnnouncementDialog> createState() => _NewAnnouncementDialogState();
}

class _NewAnnouncementDialogState extends State<_NewAnnouncementDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _level = 'info';
  int? _expiresInDays;
  var _publishNow = true;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _ready => _title.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final (_, icon, color) = _levelStyle(_level);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.muted)),
        );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: const Text('New announcement', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. New: custom categories'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _body,
                maxLines: 3,
                maxLength: 400,
                decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              label('Type'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'info', label: Text('Info'), icon: Icon(Icons.campaign_outlined)),
                  ButtonSegment(value: 'warning', label: Text('Warning'), icon: Icon(Icons.warning_amber_rounded)),
                  ButtonSegment(value: 'update', label: Text('App update'), icon: Icon(Icons.system_update_alt_outlined)),
                ],
                selected: {_level},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _level = s.first),
              ),
              const SizedBox(height: 16),
              label('Expires'),
              SegmentedButton<int?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Never')),
                  ButtonSegment(value: 1, label: Text('1 day')),
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_expiresInDays},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _expiresInDays = s.first),
              ),
              const SizedBox(height: 16),
              label('Preview in the app'),
              // Matches the app's home-screen banner.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title.text.trim().isEmpty ? 'Your title' : _title.text.trim(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          if (_body.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(_body.text.trim(), style: const TextStyle(fontSize: 12, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.close, size: 16, color: AdminColors.muted),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Off saves it hidden; switch it on later.', style: TextStyle(fontSize: 12)),
                value: _publishNow,
                onChanged: (v) => setState(() => _publishNow = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AdminColors.muted),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ready
              ? () => Navigator.pop(
                    context,
                    _Draft(_title.text.trim(), _body.text.trim(), _level, _expiresInDays, _publishNow),
                  )
              : null,
          child: Text(_publishNow ? 'Publish' : 'Save hidden'),
        ),
      ],
    );
  }
}
