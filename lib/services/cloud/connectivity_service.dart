import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has a network connection.
///
/// This is a hint, not a guarantee of internet access (a phone can be on
/// Wi-Fi with no internet). Nothing in the app depends on it for
/// correctness: Firestore queues writes until the server is actually
/// reachable. It is used to show online/offline state and to trigger a sync
/// when the connection comes back.
class ConnectivityService extends ChangeNotifier {
  /// Starts offline, then reads the current state and listens for changes.
  /// Platform errors are ignored, which leaves the last known state.
  ConnectivityService() : _online = false {
    _connectivity.checkConnectivity().then(_update).catchError((_) {});
    _sub = _connectivity.onConnectivityChanged.listen(_update, onError: (_) {});
  }

  /// Doesn't listen to the platform; tests drive it with [setOnline].
  @visibleForTesting
  ConnectivityService.manual({bool this._online = true});

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online;
  bool get isOnline => _online;

  /// Fires each time the device goes from offline to online. SyncService
  /// listens to it to push pending changes.
  final _cameOnline = StreamController<void>.broadcast();
  Stream<void> get onCameOnline => _cameOnline.stream;

  @visibleForTesting
  void setOnline(bool online) =>
      _update([online ? ConnectivityResult.wifi : ConnectivityResult.none]);

  /// Online means any connection type other than "none" (Wi-Fi, mobile
  /// data, ethernet...). Only notifies on an actual change.
  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _online) return;
    _online = online;
    if (online) _cameOnline.add(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cameOnline.close();
    super.dispose();
  }
}
