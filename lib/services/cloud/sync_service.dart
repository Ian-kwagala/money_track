import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/hive_boxes.dart';
import '../../data/money_repository.dart';
import '../../models/app_settings.dart';
import '../../models/user.dart';
import 'auth_service.dart';
import 'cloud_codec.dart';
import 'connectivity_service.dart';
import 'firebase_bootstrap.dart';

enum SyncStatus {
  /// Firebase isn't configured in this build. Local-only, as before.
  disabled,

  /// No account signed in. Local-only; changes are still tracked so they
  /// upload if this account signs back in.
  signedOut,
  syncing,
  synced,

  /// Last attempt couldn't reach the server. Local data is unaffected and
  /// changes are queued.
  offline,
  error,

  /// This phone holds data linked to a different account. Nothing syncs
  /// until the user picks what to do (see [SyncService.replaceLocalWithAccount]).
  needsAccountChoice,
}

/// Offline-first sync between the Hive boxes and Firestore.
///
/// Hive remains the source of truth the app reads from, so every screen
/// works identically with or without a connection. This service only
/// mirrors changes:
///
/// * Local → cloud: every Hive write is recorded as "dirty" (with the time
///   of the change) in the `sync_meta` box, then pushed in batches to
///   `users/{uid}/{box}/{key}`. Firestore persists queued writes on the
///   device while offline and sends them when the connection returns.
/// * Cloud → local: [syncNow] pulls documents changed since the last pull
///   and applies any that are newer than the local copy.
///
/// Conflicts are last-write-wins on the time of the edit (`updatedAtMs`).
/// The Firestore rules additionally reject a write older than what the
/// server already has, so a stale queued edit can't clobber a newer one.
/// Deletes are stored as tombstones (`deleted: true`) so they propagate.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.repo,
    required this.auth,
    required this.connectivity,
    @visibleForTesting FirebaseFirestore? firestore,
    @visibleForTesting bool? enabled,
  })  : _firestore = firestore,
        _enabled = enabled ?? FirebaseBootstrap.isReady {
    status = _enabled ? SyncStatus.signedOut : SyncStatus.disabled;
  }

  final FirebaseFirestore? _firestore;
  final bool _enabled;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  final MoneyRepository repo;
  final AuthService auth;
  final ConnectivityService connectivity;

  /// Called after cloud changes were written into Hive, so the UI refreshes.
  VoidCallback? onRemoteChangesApplied;

  static const _batchLimit = 400;
  static const _metaBox = 'sync_meta';

  late Box _meta;
  final List<StreamSubscription> _subs = [];
  final Set<String> _suppress = {};
  final Map<String, int> _inFlight = {};
  final Set<Future<void>> _commits = {};
  Timer? _flushTimer;
  Timer? _periodic;
  bool _started = false;
  bool _syncing = false;
  String? _activeUid;
  String? _pendingUid;

  late SyncStatus status;
  String? lastError;

  bool get isEnabled => status != SyncStatus.disabled;

  DateTime? get lastSyncedAt {
    if (!_started) return null;
    final ms = _meta.get('lastSyncedAt') as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  int get pendingCount =>
      _started ? _meta.keys.where((k) => k is String && k.startsWith('dirty:')).length : 0;

  /// Call once the Hive boxes are open (after MoneyRepository.init()).
  Future<void> start() async {
    if (_started || !_enabled) return;
    _meta = await Hive.openBox(_metaBox);
    _started = true;

    for (final name in CloudCodec.syncedBoxes) {
      _subs.add(repo.boxFor(name).watch().listen((e) => _onLocalEvent(name, e)));
    }
    _subs.add(auth.userChanges.listen((_) => _onAuthChanged()));
    _subs.add(connectivity.onCameOnline.listen((_) => syncNow()));
    _periodic = Timer.periodic(const Duration(minutes: 15), (_) {
      if (connectivity.isOnline) syncNow();
    });
    await _onAuthChanged();
  }

  // ---------------------------------------------------------------------------
  // Account linking
  // ---------------------------------------------------------------------------

  Future<void> _onAuthChanged() async {
    final uid = auth.uid;
    if (uid == null) {
      _activeUid = null;
      _pendingUid = null;
      _setStatus(SyncStatus.signedOut);
      return;
    }
    if (uid == _activeUid || uid == _pendingUid) return;

    final linked = _meta.get('linkedUid') as String?;
    if (linked != null && linked != uid) {
      _pendingUid = uid;
      _setStatus(SyncStatus.needsAccountChoice);
      return;
    }
    await _link(uid);
  }

  Future<void> _link(String uid) async {
    _activeUid = uid;
    _pendingUid = null;
    await _meta.put('linkedUid', uid);
    await syncNow();
  }

  /// Deletes this phone's records and loads [auth]'s account data instead.
  /// Only offered when the phone was linked to another account. The app-lock
  /// PIN is kept (it protects the device, not the account); everything else,
  /// including the previous person's profile, is wiped so none of it can be
  /// uploaded into the new account.
  Future<void> replaceLocalWithAccount() async {
    final uid = _pendingUid;
    if (uid == null) return;
    final old = repo.settings;
    final lock = AppSettings(
      appLockEnabled: old.appLockEnabled,
      appLockPin: old.appLockPin,
      appLockPasswordHash: old.appLockPasswordHash,
    );

    for (final name in CloudCodec.syncedBoxes) {
      final box = repo.boxFor(name);
      for (final k in box.keys) {
        _suppress.add('$name/$k');
      }
      await box.clear();
    }
    _suppress
      ..add('${HiveBoxes.settings}/default')
      ..add('${HiveBoxes.users}/default');
    await repo.boxFor(HiveBoxes.settings).put('default', lock);
    await repo.boxFor(HiveBoxes.users).put('default', User());
    await _meta.clear();
    onRemoteChangesApplied?.call();

    await _link(uid);
    // A brand-new account has no backup: give it the usual defaults (they
    // upload as that account's own data). Skipped if the pull failed, so
    // offline defaults can't overwrite a backup that just wasn't reachable.
    if (status == SyncStatus.synced) {
      await repo.restoreDefaultsIfEmpty();
      onRemoteChangesApplied?.call();
    }
  }

  /// Keeps this phone's data untouched and signs the other account out.
  Future<void> cancelAccountSwitch() async {
    _pendingUid = null;
    await auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Local changes → cloud
  // ---------------------------------------------------------------------------

  void _onLocalEvent(String box, BoxEvent e) {
    final key = '$box/${e.key}';
    if (_suppress.remove(key)) return;
    _meta.put('dirty:$key', DateTime.now().millisecondsSinceEpoch);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 1500), _flush);
    notifyListeners();
  }

  /// Pushes dirty records. Doesn't wait for the server: commits resolve when
  /// the server acknowledges them, which can be much later when offline.
  Future<void> _flush() async {
    final uid = _activeUid;
    if (uid == null || auth.uid != uid) return;

    final dirty = <String, int>{};
    for (final k in _meta.keys) {
      if (k is! String || !k.startsWith('dirty:')) continue;
      final key = k.substring(6);
      final gen = _meta.get(k) as int;
      if (_inFlight[key] == gen) continue;
      dirty[key] = gen;
    }
    if (dirty.isEmpty) return;

    final db = _db;
    final entries = dirty.entries.toList();
    for (var i = 0; i < entries.length; i += _batchLimit) {
      final chunk = entries.sublist(i, i + _batchLimit > entries.length ? entries.length : i + _batchLimit);
      final batch = db.batch();
      for (final entry in chunk) {
        final slash = entry.key.indexOf('/');
        final box = entry.key.substring(0, slash);
        final id = entry.key.substring(slash + 1);
        final value = repo.boxFor(box).get(id);
        batch.set(_col(uid, box).doc(id), {
          'data': value == null ? null : CloudCodec.encode(box, value as Object),
          'deleted': value == null,
          'updatedAtMs': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _inFlight[entry.key] = entry.value;
      }
      late final Future<void> commit;
      commit = batch.commit().then((_) async {
        for (final entry in chunk) {
          _inFlight.remove(entry.key);
          await _meta.put('ts:${entry.key}', entry.value);
          // Only clear if the record wasn't edited again since this push.
          if (_meta.get('dirty:${entry.key}') == entry.value) {
            await _meta.delete('dirty:${entry.key}');
          }
        }
        notifyListeners();
      }, onError: (Object e) {
        for (final entry in chunk) {
          _inFlight.remove(entry.key);
        }
        // permission-denied here usually means the server holds a newer
        // version of one of these records; a full sync pulls it first.
        if (e is FirebaseException && e.code == 'permission-denied') {
          Future.delayed(const Duration(seconds: 2), syncNow);
        } else {
          _fail(e);
        }
      }).whenComplete(() => _commits.remove(commit));
      _commits.add(commit);
    }
  }

  /// Pushes pending changes immediately and waits for the server to accept
  /// them (the app itself never waits like this).
  @visibleForTesting
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    await _flush();
    while (_commits.isNotEmpty) {
      await Future.wait(_commits.toList());
    }
  }

  // ---------------------------------------------------------------------------
  // Full sync: pull, then push
  // ---------------------------------------------------------------------------

  Future<void> syncNow() async {
    final uid = _activeUid;
    if (!_started || uid == null || _syncing) return;
    _syncing = true;
    _setStatus(SyncStatus.syncing);
    try {
      final changed = await _pull(uid);
      if (changed) onRemoteChangesApplied?.call();

      // First sync for this account on this phone: upload everything that
      // exists locally but has never been synced (after the pull, so cloud
      // copies of shared defaults win over this phone's fresh ones).
      if (_meta.get('initialUploadDone') != true) {
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final name in CloudCodec.syncedBoxes) {
          for (final k in repo.boxFor(name).keys) {
            final key = '$name/$k';
            if (_meta.get('ts:$key') == null && _meta.get('dirty:$key') == null) {
              await _meta.put('dirty:$key', now);
            }
          }
        }
        await _meta.put('initialUploadDone', true);
      }

      await _flush();
      _writeProfile(uid);
      await _meta.put('lastSyncedAt', DateTime.now().millisecondsSinceEpoch);
      lastError = null;
      _setStatus(SyncStatus.synced);
    } catch (e) {
      _fail(e);
    } finally {
      _syncing = false;
    }
  }

  /// Returns true if any local record changed.
  Future<bool> _pull(String uid) async {
    var changed = false;
    for (final name in CloudCodec.syncedBoxes) {
      final box = repo.boxFor(name);
      var since = (_meta.get('lastPull:$name') as int?) ?? 0;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> q = _col(uid, name)
            .where('updatedAtMs', isGreaterThanOrEqualTo: since)
            .orderBy('updatedAtMs')
            .limit(_batchLimit);
        if (cursor != null) q = q.startAfterDocument(cursor);
        // Server only: a cache read could advance lastPull past documents
        // this phone hasn't actually seen yet.
        final snap = await q.get(const GetOptions(source: Source.server));
        for (final doc in snap.docs) {
          if (await _applyRemote(name, box, doc)) changed = true;
          final ms = (doc.data()['updatedAtMs'] as num?)?.toInt() ?? 0;
          if (ms > since) since = ms;
        }
        await _meta.put('lastPull:$name', since);
        if (snap.docs.length < _batchLimit) break;
        cursor = snap.docs.last;
      }
    }
    return changed;
  }

  Future<bool> _applyRemote(String name, Box box, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final m = doc.data();
    if (m == null) return false;
    final key = '$name/${doc.id}';
    final remoteMs = (m['updatedAtMs'] as num?)?.toInt() ?? 0;
    final localMs = [
      (_meta.get('ts:$key') as int?) ?? 0,
      (_meta.get('dirty:$key') as int?) ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    if (remoteMs <= localMs) return false;

    if (m['deleted'] == true) {
      if (box.containsKey(doc.id)) {
        _suppress.add(key);
        await box.delete(doc.id);
      }
    } else {
      final data = m['data'];
      if (data is! Map<String, dynamic>) return false;
      _suppress.add(key);
      await box.put(doc.id, CloudCodec.decode(name, data, existing: box.get(doc.id)));
    }
    await _meta.put('ts:$key', remoteMs);
    await _meta.delete('dirty:$key');
    return true;
  }

  /// Summary document the admin dashboard reads. Never contains the PIN.
  void _writeProfile(String uid) {
    final user = repo.currentUser;
    final settings = repo.settings;
    _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': auth.email,
      'displayName': (auth.displayName?.isNotEmpty ?? false) ? auth.displayName : user.name,
      'phone': user.phone,
      'occupation': user.occupation,
      'incomeType': user.incomeType.name,
      'currencyCode': settings.currencyCode,
      'platform': defaultTargetPlatform.name,
      if (auth.accountCreatedAt != null) 'createdAt': Timestamp.fromDate(auth.accountCreatedAt!),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'counts': {
        'wallets': repo.wallets.length,
        'transactions': repo.transactions.length,
        'budgets': repo.budgets.length,
        'savingsGoals': repo.savingsGoals.length,
        'bills': repo.bills.length,
        'debts': repo.debts.length,
      },
    }, SetOptions(merge: true)).catchError((Object e) => debugPrint('Profile write failed: $e'));
  }

  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _col(String uid, String box) =>
      _db.collection('users').doc(uid).collection(box);

  void _fail(Object e) {
    final offline = e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded');
    lastError = offline ? null : e.toString();
    _setStatus(offline || !connectivity.isOnline ? SyncStatus.offline : SyncStatus.error);
  }

  void _setStatus(SyncStatus s) {
    status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _flushTimer?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
