import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// One SMS as the phone delivered it.
class RawSms {
  final String sender;
  final String body;
  final DateTime receivedAt;

  const RawSms({required this.sender, required this.body, required this.receivedAt});
}

enum SmsAccess {
  granted,

  /// Not allowed yet; asking again shows Android's permission dialog.
  denied,

  /// Android won't ask again: the user has to allow it in App info. Apps
  /// installed from an APK on Android 15+ first need "Allow restricted
  /// settings" there.
  blocked,

  /// Not Android, so SMS can't be read at all.
  unsupported,
}

/// The phone's SMS, as far as auto-capture needs it. Messages from personal
/// phone numbers are dropped on the native side and never reach Dart.
abstract class SmsBridge {
  factory SmsBridge.platform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? AndroidSmsBridge() : const UnsupportedSmsBridge();

  bool get isSupported;
  Future<SmsAccess> access();
  Future<SmsAccess> requestAccess();

  /// Opens this app's App info page in Android settings.
  Future<void> openSettings();

  /// Asks to show notifications (Android 13+), for "new transaction" alerts.
  /// Auto-capture works without it; only the alerts are lost.
  Future<void> askToNotify();

  /// Turns the background SMS receiver on or off. It keeps working while the
  /// app is closed, so this is remembered on the native side too.
  Future<void> setListening(bool on);

  /// Messages that arrived since the last call, oldest first. Clears them.
  Future<List<RawSms>> takeQueued();

  /// Inbox messages received at or after [since], oldest first.
  Future<List<RawSms>> readInbox({required DateTime since});

  /// Fires when a new SMS has been queued while the app is open.
  Stream<void> get onQueued;
}

class AndroidSmsBridge implements SmsBridge {
  AndroidSmsBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'queued') _queued.add(null);
    });
  }

  static const _channel = MethodChannel('money_track/sms');
  final _queued = StreamController<void>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Future<SmsAccess> access() async => _accessFrom(await Permission.sms.status);

  @override
  Future<SmsAccess> requestAccess() async => _accessFrom(await Permission.sms.request());

  static SmsAccess _accessFrom(PermissionStatus status) {
    if (status.isGranted) return SmsAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) return SmsAccess.blocked;
    return SmsAccess.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();

  @override
  Future<void> askToNotify() => Permission.notification.request();

  @override
  Future<void> setListening(bool on) => _channel.invokeMethod<void>('setListening', on);

  @override
  Future<List<RawSms>> takeQueued() async => _decode(await _channel.invokeListMethod<Object?>('takeQueued'));

  @override
  Future<List<RawSms>> readInbox({required DateTime since}) async =>
      _decode(await _channel.invokeListMethod<Object?>('readInbox', since.millisecondsSinceEpoch));

  @override
  Stream<void> get onQueued => _queued.stream;

  static List<RawSms> _decode(List<Object?>? raw) => [
        for (final m in raw ?? const <Object?>[])
          if (m is Map && m['body'] is String)
            RawSms(
              sender: m['sender'] as String? ?? '',
              body: m['body'] as String,
              receivedAt: DateTime.fromMillisecondsSinceEpoch((m['receivedAt'] as num?)?.toInt() ?? 0),
            ),
      ];
}

/// iPhone, web and desktop: no SMS access, so only pasted messages work.
class UnsupportedSmsBridge implements SmsBridge {
  const UnsupportedSmsBridge();

  @override
  bool get isSupported => false;
  @override
  Future<SmsAccess> access() async => SmsAccess.unsupported;
  @override
  Future<SmsAccess> requestAccess() async => SmsAccess.unsupported;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> askToNotify() async {}
  @override
  Future<void> setListening(bool on) async {}
  @override
  Future<List<RawSms>> takeQueued() async => const [];
  @override
  Future<List<RawSms>> readInbox({required DateTime since}) async => const [];
  @override
  Stream<void> get onQueued => const Stream.empty();
}
