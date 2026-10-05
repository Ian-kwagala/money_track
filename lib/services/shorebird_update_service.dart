import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Where [ShorebirdUpdateService] currently is in the check/download cycle.
enum ShorebirdUpdateState {
  idle,
  checking,
  upToDate,
  downloading,
  restartRequired,
  error,
}

/// Wraps [ShorebirdUpdater] so the rest of the app (e.g. the Settings
/// screen) can show patch status without depending on the Shorebird
/// package directly.
///
/// Does nothing on a build that wasn't produced with `shorebird release` /
/// `shorebird patch` — [isAvailable] is false there (debug builds, plain
/// `flutter build`, unsupported platforms), and every method below is a
/// no-op in that case.
class ShorebirdUpdateService extends ChangeNotifier {
  ShorebirdUpdateService() : _updater = ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  bool get isAvailable => _updater.isAvailable;

  Patch? currentPatch;
  ShorebirdUpdateState state = ShorebirdUpdateState.idle;
  String? errorMessage;

  bool get isBusy =>
      state == ShorebirdUpdateState.checking ||
      state == ShorebirdUpdateState.downloading;

  /// Reads the currently installed patch number, if any. Safe to call even
  /// when Shorebird isn't available.
  Future<void> loadCurrentPatch() async {
    if (!isAvailable) return;
    try {
      currentPatch = await _updater.readCurrentPatch();
      notifyListeners();
    } catch (_) {
      // Non-fatal: leave currentPatch as-is.
    }
  }

  /// Checks the stable track for a new patch and, if one exists, downloads
  /// it in the background. The patch takes effect the next time the app is
  /// fully restarted — it is never applied while running.
  ///
  /// Safe to call from app startup (fire-and-forget) or from a user-tapped
  /// "Check for updates" button; both paths share this method.
  Future<void> checkForUpdate() async {
    if (!isAvailable || isBusy) return;
    state = ShorebirdUpdateState.checking;
    errorMessage = null;
    notifyListeners();

    try {
      final status = await _updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.outdated:
          state = ShorebirdUpdateState.downloading;
          notifyListeners();
          await _updater.update();
          state = ShorebirdUpdateState.restartRequired;
        case UpdateStatus.restartRequired:
          state = ShorebirdUpdateState.restartRequired;
        case UpdateStatus.upToDate:
          state = ShorebirdUpdateState.upToDate;
        case UpdateStatus.unavailable:
          state = ShorebirdUpdateState.idle;
      }
    } on UpdateException catch (e) {
      state = ShorebirdUpdateState.error;
      errorMessage = e.message;
    } catch (e) {
      state = ShorebirdUpdateState.error;
      errorMessage = e.toString();
    }

    await loadCurrentPatch();
    notifyListeners();
  }
}
