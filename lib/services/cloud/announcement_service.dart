import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_bootstrap.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String body;

  /// 'info', 'warning' or 'update' (set from the admin dashboard).
  final String level;
  final DateTime? expiresAt;
}

/// Messages published from the admin dashboard.
///
/// Readable without an account. Served from Firestore's on-device cache when
/// offline, so the last-seen announcements still show without a connection.
class AnnouncementService extends ChangeNotifier {
  AnnouncementService() {
    if (!FirebaseBootstrap.isReady) return;
    _loadDismissed();
    _sub = FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen(_onSnapshot, onError: (Object e) => debugPrint('Announcements unavailable: $e'));
  }

  static const _prefsKey = 'dismissed_announcements';

  StreamSubscription? _sub;
  List<Announcement> _items = const [];
  Set<String> _dismissed = {};

  List<Announcement> get visible {
    final now = DateTime.now();
    return _items
        .where((a) => !_dismissed.contains(a.id))
        .where((a) => a.expiresAt == null || a.expiresAt!.isAfter(now))
        .toList();
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    _items = snap.docs.map((d) {
      final m = d.data();
      return Announcement(
        id: d.id,
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        level: (m['level'] as String?) ?? 'info',
        expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissed = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    notifyListeners();
  }

  Future<void> dismiss(String id) async {
    _dismissed.add(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _dismissed.toList());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
