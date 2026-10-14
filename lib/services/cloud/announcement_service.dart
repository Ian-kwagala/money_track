import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_bootstrap.dart';

/// One message from the admin dashboard, read from the `announcements`
/// Firestore collection.
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

  /// After this moment the announcement stops showing; null never expires.
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
    // Live query: the newest five active announcements. The dashboard can
    // publish or retire one and it shows up or disappears without a restart.
    _sub = FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen(_onSnapshot, onError: (Object e) => debugPrint('Announcements unavailable: $e'));
  }

  /// SharedPreferences key holding the IDs the user has closed. Kept on the
  /// device only, so a dismissed message stays hidden after a restart.
  static const _prefsKey = 'dismissed_announcements';

  StreamSubscription? _sub;
  List<Announcement> _items = const [];
  Set<String> _dismissed = {};

  /// Announcements to show now: not dismissed and not expired.
  List<Announcement> get visible {
    final now = DateTime.now();
    return _items
        .where((a) => !_dismissed.contains(a.id))
        .where((a) => a.expiresAt == null || a.expiresAt!.isAfter(now))
        .toList();
  }

  /// Converts the Firestore documents, tolerating missing fields.
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

  /// Hides [id] immediately, then remembers it on the device.
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
