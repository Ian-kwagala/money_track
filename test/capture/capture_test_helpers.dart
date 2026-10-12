import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:money_track/data/money_repository.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/services/capture/sms_bridge.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';

/// Stands in for the Android side: an inbox, a queue of newly arrived SMS
/// and a permission answer.
class FakeSmsBridge implements SmsBridge {
  SmsAccess current = SmsAccess.denied;
  SmsAccess answer = SmsAccess.granted;
  bool listening = false;
  bool askedToNotify = false;
  final inbox = <RawSms>[];
  final queue = <RawSms>[];
  final inboxReadsSince = <DateTime>[];
  final _queued = StreamController<void>.broadcast();

  /// An SMS arriving while the app is open.
  void arrive(RawSms sms) {
    queue.add(sms);
    _queued.add(null);
  }

  @override
  bool get isSupported => true;
  @override
  Future<SmsAccess> access() async => current;
  @override
  Future<SmsAccess> requestAccess() async => current = answer;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> askToNotify() async => askedToNotify = true;
  @override
  Future<void> setListening(bool on) async => listening = on;
  @override
  Future<List<RawSms>> takeQueued() async {
    final out = [...queue];
    queue.clear();
    return out;
  }

  @override
  Future<List<RawSms>> readInbox({required DateTime since}) async {
    inboxReadsSince.add(since);
    return inbox.where((m) => !m.receivedAt.isBefore(since)).toList();
  }

  @override
  Stream<void> get onQueued => _queued.stream;
}

/// One phone: its own storage, view model and capture service.
class Phone {
  Phone._(this.dir, this.vm, this.capture, this.bridge);

  final Directory dir;
  final TrackerViewModel vm;
  final CaptureService capture;
  final FakeSmsBridge bridge;
  static DateTime now = DateTime(2026, 10, 12, 9, 0);

  static Future<Phone> boot({Directory? dir, FakeSmsBridge? bridge}) async {
    dir ??= await Directory.systemTemp.createTemp('mt_capture_test');
    final repo = MoneyRepository();
    await repo.init(hivePath: dir.path);
    final vm = TrackerViewModel(repo);
    bridge ??= FakeSmsBridge();
    final capture = CaptureService(vm: vm, bridge: bridge, clock: () => now);
    await capture.start(watchLifecycle: false);
    return Phone._(dir, vm, capture, bridge);
  }

  Future<void> shutdown() async {
    capture.dispose();
    await Hive.close();
  }

  /// Closes everything and boots again on the same storage.
  Future<Phone> restart() async {
    await shutdown();
    return boot(dir: dir, bridge: bridge);
  }

  TxRecord? tx(String id) {
    for (final t in vm.transactions) {
      if (t.id == id) return t;
    }
    return null;
  }
}

RawSms sms(String body, {DateTime? at, String sender = 'AirtelMoney'}) =>
    RawSms(sender: sender, body: body, receivedAt: at ?? DateTime(2026, 10, 5, 8, 0));

const airtelSent = 'SENT UGX 21,000 to GRACE AKELLO on 256700345. Fee UGX 500.0 Bal UGX 11,450. TID 157700004.';
const airtelSent2 = 'SENT UGX 8,000 to GRACE AKELLO on 256700345. Fee UGX 300.0 Bal UGX 3,150. TID 157700005.';
const airtelReceived =
    'RECEIVED UGX 51,000 from 2567000102,JANE NAMUKASA,1234. Balance UGX 51,675. TID:1581400001.';
const airtelPaid = 'PAID UGX 31,000 to AM Global Pay Charge UGX 0, TID 1580700002. '
    'Bal UGX 2,675 Date: 05-October-2026 06:38.';
const airtelDeposit = 'Cash deposit of UGX 31,200 from CENTENARY BANK. Balance UGX 33,675. '
    'Trans ID:158000003. Date 05-October-2026 06:15.';
const umeme = 'PAID UGX 5,000 to UMEME LIMITED Charge UGX 0, TID 1580700099. Bal UGX 2,675';
const nssfInterest = 'Dear JOHN OKELLO MUGISHA, your Smartlife account - SL10000000001, has been '
    'credited with UGX.116 interest for 2026-09. New Balance: UGX.10331. A Better Life.';
const promo = "Y'ello! Get 1GB for UGX 1,000 valid 24hrs. Dial *157# now.";

/// Waits (in real time) until [done] is true; fails after a few seconds.
Future<void> until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) throw StateError('Timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  // Let whatever runs right after (e.g. showing a dialog) happen too.
  await Future<void>.delayed(const Duration(milliseconds: 10));
}
