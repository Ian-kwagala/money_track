import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/hive_boxes.dart';
import '../../models/captured_sms.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import 'capture_suggestions.dart';
import 'money_message.dart';
import 'money_message_parser.dart';
import 'sms_bridge.dart';

/// A captured SMS with what the current parser reads from it.
class Capture {
  /// What's stored on the phone.
  final CapturedSms record;

  /// [record]'s body parsed just now; never stored.
  final ParsedMoneyMessage message;

  const Capture(this.record, this.message);

  String get id => record.id;

  /// When the transaction happened: the date in the SMS, else its arrival.
  DateTime get when => message.occurredAt ?? record.receivedAt;
}

/// A wallet whose balance in the app differs from what its newest SMS says.
class BalanceMismatch {
  final String walletId;
  final double smsBalance;
  final double appBalance;

  const BalanceMismatch({required this.walletId, required this.smsBalance, required this.appBalance});
}

/// Outcome of [CaptureService.turnOn], so the UI can explain what to do next.
enum TurnOnResult { on, denied, blocked, unsupported }

/// Auto-capture: collects money SMS, keeps them for review on this phone,
/// and turns the ones the user confirms into transactions.
///
/// Nothing here is synced. Raw messages stay on the phone and handled ones
/// are deleted after [keepHandledFor]; only confirmed transactions reach
/// the cloud, through the normal transaction sync.
class CaptureService extends ChangeNotifier with WidgetsBindingObserver {
  CaptureService({
    required this.vm,
    required this.bridge,
    this.parser = const MoneyMessageParser(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final TrackerViewModel vm;
  final SmsBridge bridge;
  final MoneyMessageParser parser;
  final DateTime Function() _now;

  /// How far back the inbox is read when auto-capture is first turned on.
  static const firstScan = Duration(days: 30);

  /// Confirmed and ignored messages are deleted this long after arriving.
  static const keepHandledFor = Duration(days: 60);

  /// Each inbox scan reaches back this far past the previous one, in case
  /// the SMS app wrote a message to the inbox a little after it arrived.
  static const scanOverlap = Duration(days: 1);

  // Keys in the capture_meta box. It also holds the wallet:/category: memory
  // keys described in CaptureSuggestions.memory.
  static const _onKey = 'on';
  static const _lastScanKey = 'lastScanMs';

  // Null until [start] has opened them.
  Box<CapturedSms>? _box;
  Box<dynamic>? _meta;
  StreamSubscription<void>? _queuedSub;
  SmsAccess _access = SmsAccess.denied;
  bool _watchingLifecycle = false;

  // [refresh] runs one at a time; a call made while one is running sets
  // _refreshAgain so the running one loops once more instead.
  bool _refreshing = false;
  bool _refreshAgain = false;

  /// Cached parse of the pending list; cleared by [_changed].
  List<Capture>? _pending;

  bool get isReady => _box != null;
  bool get isSupported => bridge.isSupported;
  bool get isOn => _meta?.get(_onKey) == true;
  SmsAccess get access => _access;

  /// Turned on, but SMS permission has since been taken away.
  bool get needsPermission => isOn && _access != SmsAccess.granted;

  /// Waiting for review, newest first.
  List<Capture> get pending => _pending ??= _captures((r) => r.status == CaptureStatus.pending);

  int get pendingCount => pending.length;

  /// Confirmed or ignored in the last week, newest first, for undo.
  List<Capture> get recentlyHandled {
    final since = _now().subtract(const Duration(days: 7));
    return _captures((r) => r.status != CaptureStatus.pending && (r.handledAt?.isAfter(since) ?? false))
      ..sort((a, b) => b.record.handledAt!.compareTo(a.record.handledAt!));
  }

  /// Opens the capture boxes, clears out old messages and, if auto-capture
  /// is on, collects anything that arrived while the app was closed. Called
  /// once local storage is ready (see main.dart). [watchLifecycle] is false
  /// in tests.
  Future<void> start({bool watchLifecycle = true}) async {
    // 19/20 are the typeIds of CaptureStatus and CapturedSms.
    if (!Hive.isAdapterRegistered(19)) Hive.registerAdapter(CaptureStatusAdapter());
    if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(CapturedSmsAdapter());
    _box = await Hive.openBox<CapturedSms>(HiveBoxes.capturedSms);
    _meta = await Hive.openBox<dynamic>(HiveBoxes.captureMeta);
    await _deleteOld();
    if (watchLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _watchingLifecycle = true;
    }
    _queuedSub = bridge.onQueued.listen((_) => refresh());
    _access = await bridge.access();
    _changed();
    if (isOn && _access == SmsAccess.granted) {
      // The native receiver keeps its own on/off flag; make sure it agrees.
      await bridge.setListening(true);
      await refresh();
    }
  }

  /// Coming back to the app picks up SMS received while it was in the
  /// background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isOn) refresh();
  }

  @override
  void dispose() {
    if (_watchingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _queuedSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // On / off
  // ---------------------------------------------------------------------------

  /// Asks for SMS permission, starts listening and imports the last
  /// [firstScan] of money messages.
  Future<TurnOnResult> turnOn() async {
    if (!isSupported) return TurnOnResult.unsupported;
    _access = await bridge.requestAccess();
    if (_access != SmsAccess.granted) {
      _changed();
      return _access == SmsAccess.blocked ? TurnOnResult.blocked : TurnOnResult.denied;
    }
    await bridge.askToNotify();
    await bridge.setListening(true);
    await _meta!.put(_onKey, true);
    _changed();
    await refresh();
    return TurnOnResult.on;
  }

  /// Stops the background receiver. Messages already captured are kept.
  Future<void> turnOff() async {
    await bridge.setListening(false);
    await _meta!.put(_onKey, false);
    _changed();
  }

  Future<void> openSettings() => bridge.openSettings();

  // ---------------------------------------------------------------------------
  // Collecting messages
  // ---------------------------------------------------------------------------

  /// Picks up messages queued since the app last looked, plus the inbox
  /// since the previous scan ([firstScan] back on the first run, or when
  /// [rescan] is set). Returns how many new ones need review.
  Future<int> refresh({bool rescan = false}) async {
    if (!isReady || !isOn) return 0;
    if (_refreshing) {
      _refreshAgain = true;
      return 0;
    }
    _refreshing = true;
    var added = 0;
    try {
      do {
        _refreshAgain = false;
        _access = await bridge.access();
        final messages = [...await bridge.takeQueued()];
        if (_access == SmsAccess.granted) {
          final now = _now();
          final last = _meta!.get(_lastScanKey) as int?;
          final since = rescan || last == null
              ? now.subtract(firstScan)
              : DateTime.fromMillisecondsSinceEpoch(last).subtract(scanOverlap);
          messages.addAll(await bridge.readInbox(since: since));
          await _meta!.put(_lastScanKey, now.millisecondsSinceEpoch);
        }
        added += await ingest(messages);
        rescan = false;
      } while (_refreshAgain);
    } catch (e) {
      debugPrint('Auto-capture refresh failed: $e');
    } finally {
      _refreshing = false;
      _changed();
    }
    return added;
  }

  /// Stores the money messages among [messages] for review. Anything the
  /// parser doesn't recognise is dropped without being stored, as are
  /// messages (or transactions) already captured. Returns how many are new.
  Future<int> ingest(Iterable<RawSms> messages) async {
    final box = _box!;
    final seenKeys = {for (final r in box.values) r.dedupeKey};
    var added = 0;
    // Two layers of de-duplication: the same text (fingerprint) and the same
    // transaction worded differently (dedupeKey).
    for (final sms in messages) {
      final id = fingerprint(sms.body);
      if (box.containsKey(id)) continue;
      final m = parser.parse(sms.body, sender: sms.sender.isEmpty ? null : sms.sender, receivedAt: sms.receivedAt);
      if (m == null || !seenKeys.add(m.dedupeKey)) continue;
      final record = CapturedSms(id: id, dedupeKey: m.dedupeKey, sender: sms.sender, body: sms.body, receivedAt: sms.receivedAt);
      // Already confirmed on another phone and restored from the cloud.
      final existing = [for (final txId in _transactionIdsFor(id)) if (_hasTransaction(txId)) txId];
      if (existing.isNotEmpty) {
        record
          ..status = CaptureStatus.confirmed
          ..transactionIds = existing
          ..handledAt = _now();
      } else {
        added++;
      }
      await box.put(id, record);
    }
    _changed();
    return added;
  }

  /// Adds a pasted message to the review list. False when it isn't a money
  /// message or is already there.
  Future<bool> addPasted(String body) async {
    if (!isReady) return false;
    return await ingest([RawSms(sender: '', body: body.trim(), receivedAt: _now())]) > 0;
  }

  /// Same text, same fingerprint, however its whitespace was laid out.
  static String fingerprint(String body) =>
      sha1.convert(utf8.encode(body.replaceAll(RegExp(r'\s+'), ' ').trim())).toString();

  // ---------------------------------------------------------------------------
  // Reviewing
  // ---------------------------------------------------------------------------

  /// A suggestions engine over the current wallets and categories, plus the
  /// user's past choices read from the meta box.
  CaptureSuggestions get suggestions => CaptureSuggestions(
        wallets: vm.wallets,
        categories: vm.categories,
        memory: {
          for (final k in _meta?.keys ?? const <dynamic>[])
            if (k is String && (k.startsWith('wallet:') || k.startsWith('category:')) && _meta!.get(k) is String)
              k: _meta!.get(k) as String,
        },
      );

  /// The suggested way to record [c], before the user edits anything.
  CaptureDraft draftFor(Capture c) => suggestions.draftFor(c.message, fallbackTime: c.record.receivedAt);

  /// A transaction already in the app that looks like this one — same type,
  /// amount and wallet within a day — e.g. one typed in by hand.
  TxRecord? possibleDuplicate(Capture c, [CaptureDraft? draft]) {
    final d = draft ?? draftFor(c);
    for (final t in vm.transactions) {
      if (t.id.startsWith('sms_')) continue; // other captures are de-duplicated already
      if (t.type != d.type || (t.amount - d.amount).abs() >= 1) continue;
      if (t.walletId != d.walletId || (d.type == TxType.transfer && t.toWalletId != d.toWalletId)) continue;
      if (t.dateTime.difference(d.dateTime).abs() > const Duration(days: 1)) continue;
      return t;
    }
    return null;
  }

  /// Records [c] as a transaction (plus its fee as a separate expense) and
  /// remembers the wallet and category for next time. [draft] is the user's
  /// edited version; without one, the suggestion is used as is.
  ///
  /// Returns a mismatch when this is the newest news about the provider's
  /// wallet and the app's balance doesn't match what the SMS says.
  Future<BalanceMismatch?> confirm(Capture c, [CaptureDraft? draft]) async {
    final d = draft ?? draftFor(c);
    if (!d.isComplete) throw StateError('Choose a wallet and category first');
    final ids = _transactionIdsFor(c.id);
    await vm.addTransaction(TxRecord(
      id: ids.first,
      type: d.type,
      amount: d.amount,
      walletId: d.walletId!,
      toWalletId: d.type == TxType.transfer ? d.toWalletId : null,
      categoryId: d.type == TxType.transfer ? '' : d.categoryId!,
      note: d.note,
      dateTime: d.dateTime,
    ));
    final created = [ids.first];

    // The fee is charged by the provider, so it comes out of the provider's
    // wallet even when the main record is a transfer.
    final providerWallet = _providerWallet(c, d);
    if (d.fee > 0 && providerWallet != null) {
      await _ensureFeesCategory();
      await vm.addTransaction(TxRecord(
        id: ids.last,
        type: TxType.expense,
        amount: d.fee,
        walletId: providerWallet,
        categoryId: CaptureSuggestions.feesCategoryId,
        note: 'Fee · ${d.note}',
        dateTime: d.dateTime,
      ));
      created.add(ids.last);
    }

    // Remember the user's choices so the next message from this provider or
    // counterparty is pre-filled the same way. Interest is skipped: its
    // "counterparty" is the bank, not a payee.
    if (providerWallet != null) {
      await _meta!.put(CaptureSuggestions.walletMemoryKey(c.message.provider, c.message.account), providerWallet);
    }
    final categoryKey = CaptureSuggestions.categoryMemoryKey(c.message.counterparty);
    if (categoryKey != null && d.type != TxType.transfer && c.message.kind != MoneyMessageKind.interest) {
      await _meta!.put(categoryKey, d.categoryId);
    }

    c.record
      ..status = CaptureStatus.confirmed
      ..transactionIds = created
      ..handledAt = _now();
    await c.record.save();
    _changed();
    return balanceCheck(c, providerWallet);
  }

  /// Confirms every waiting message whose suggestion is complete and that
  /// doesn't look like a duplicate, oldest first. Returns how many were
  /// confirmed and the balance mismatches found, at most one per wallet.
  Future<({int confirmed, int skipped, List<BalanceMismatch> mismatches})> confirmAll() async {
    final queue = pending.reversed.toList();
    final mismatches = <String, BalanceMismatch>{};
    var confirmed = 0;
    for (final c in queue) {
      final d = draftFor(c);
      if (!d.isComplete || possibleDuplicate(c, d) != null) continue;
      final mismatch = await confirm(c, d);
      if (mismatch != null) mismatches[mismatch.walletId] = mismatch;
      confirmed++;
    }
    return (confirmed: confirmed, skipped: queue.length - confirmed, mismatches: mismatches.values.toList());
  }

  /// Marks [c] as not worth recording. Can be undone for a week.
  Future<void> ignore(Capture c) async {
    c.record
      ..status = CaptureStatus.ignored
      ..handledAt = _now();
    await c.record.save();
    _changed();
  }

  /// Puts a confirmed or ignored message back for review, removing any
  /// transactions confirming it created.
  Future<void> undo(Capture c) async {
    for (final id in c.record.transactionIds) {
      if (_hasTransaction(id)) await vm.deleteTransaction(id);
    }
    c.record
      ..status = CaptureStatus.pending
      ..transactionIds = []
      ..handledAt = null;
    await c.record.save();
    _changed();
  }

  /// Compares the app's balance for [walletId] with the balance [c] reports,
  /// when [c] is the newest thing known about that wallet.
  BalanceMismatch? balanceCheck(Capture c, String? walletId) {
    final smsBalance = c.message.balance;
    if (smsBalance == null || walletId == null) return null;
    // If anything newer touched this wallet, the SMS balance is out of date
    // and comparing would raise a false alarm.
    final newerTransaction = vm.transactions.any((t) =>
        (t.walletId == walletId || t.toWalletId == walletId) &&
        t.dateTime.isAfter(c.when) &&
        !c.record.transactionIds.contains(t.id));
    final newerPending = pending.any((p) => p.id != c.id && p.message.provider == c.message.provider && p.when.isAfter(c.when));
    if (newerTransaction || newerPending) return null;
    final appBalance = vm.walletBalance(walletId);
    // Differences under 1 are rounding, not a real mismatch.
    if ((appBalance - smsBalance).abs() < 1) return null;
    return BalanceMismatch(walletId: walletId, smsBalance: smsBalance, appBalance: appBalance);
  }

  /// Sets the wallet to the SMS balance. Earlier transactions are kept; the
  /// wallet's opening balance absorbs the difference.
  Future<void> matchBalance(BalanceMismatch m) => vm.setWalletBalance(vm.walletById(m.walletId), m.smsBalance);

  // ---------------------------------------------------------------------------

  /// The wallet the provider's balance and fee belong to: where money
  /// arrived for incoming messages, where it left from for outgoing ones.
  static String? _providerWallet(Capture c, CaptureDraft d) =>
      c.message.kind.isMoneyIn && d.type == TxType.transfer ? d.toWalletId : d.walletId;

  /// Fixed per message, so a message confirmed on two phones (or undone and
  /// confirmed again) never makes two copies.
  static List<String> _transactionIdsFor(String captureId) => ['sms_$captureId', 'sms_${captureId}_fee'];

  bool _hasTransaction(String id) => vm.transactions.any((t) => t.id == id);

  /// Creates the "Fees & Charges" category the first time a fee is recorded.
  Future<void> _ensureFeesCategory() async {
    if (vm.categoryById(CaptureSuggestions.feesCategoryId) != null) return;
    await vm.addCategory(Category(
      id: CaptureSuggestions.feesCategoryId,
      name: 'Fees & Charges',
      icon: 'receipt_long',
      color: 0xFF64748B,
      type: TxType.expense,
      isBuiltIn: true,
    ));
  }

  /// Stored messages matching [include], each re-parsed with the current
  /// parser, newest first. Ones the parser no longer understands are left
  /// out.
  List<Capture> _captures(bool Function(CapturedSms) include) {
    final out = <Capture>[];
    for (final r in _box?.values ?? const <CapturedSms>[]) {
      if (!include(r)) continue;
      final m = parser.parse(r.body, sender: r.sender.isEmpty ? null : r.sender, receivedAt: r.receivedAt);
      if (m != null) out.add(Capture(r, m));
    }
    return out..sort((a, b) => b.when.compareTo(a.when));
  }

  /// Handled messages past [keepHandledFor], and waiting ones the current
  /// parser no longer recognises.
  Future<void> _deleteOld() async {
    final cutoff = _now().subtract(keepHandledFor);
    final old = [
      for (final r in _box!.values)
        if (r.receivedAt.isBefore(cutoff) &&
            (r.status != CaptureStatus.pending ||
                parser.parse(r.body, sender: r.sender.isEmpty ? null : r.sender, receivedAt: r.receivedAt) == null))
          r.id,
    ];
    await _box!.deleteAll(old);
  }

  /// Drops the cached pending list and tells listeners to rebuild.
  void _changed() {
    _pending = null;
    notifyListeners();
  }
}
