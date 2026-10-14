import 'package:hive_flutter/hive_flutter.dart';

part 'captured_sms.g.dart';

/// Where a captured money SMS is in the user's review.
@HiveType(typeId: 19)
enum CaptureStatus {
  /// Waiting in the review list for the user to confirm or ignore.
  @HiveField(0)
  pending,

  /// Turned into transactions (see [CapturedSms.transactionIds]).
  @HiveField(1)
  confirmed,

  /// Dismissed by the user; no transactions were created.
  @HiveField(2)
  ignored,
}

/// A money SMS that auto-capture recognised, waiting for (or done with) the
/// user's review.
///
/// Lives only on this phone: it's never synced, and handled ones are deleted
/// after [CaptureService.keepHandledFor]. The parsed details aren't stored —
/// [body] is re-read with the current parser whenever it's shown, so a parser
/// fix shipped as a patch also fixes messages already waiting for review.
@HiveType(typeId: 20)
class CapturedSms extends HiveObject {
  /// Fingerprint of the message text, so the same SMS seen twice (as it
  /// arrives, then again in an inbox scan) is stored once.
  @HiveField(0)
  String id;

  /// [ParsedMoneyMessage.dedupeKey] when it was captured: catches the same
  /// transaction arriving in two differently worded messages.
  @HiveField(1)
  String dedupeKey;

  /// SMS sender ID ("AirtelMoney"); empty for a pasted message.
  @HiveField(2)
  String sender;

  /// The full SMS text, kept so it can be re-parsed (see the class doc).
  @HiveField(3)
  String body;

  /// When the phone received the SMS (or when it was pasted in).
  @HiveField(4)
  DateTime receivedAt;

  @HiveField(5)
  CaptureStatus status;

  /// Transactions created when it was confirmed (the amount, plus the fee
  /// if any), so undo can remove exactly those.
  @HiveField(6)
  List<String> transactionIds;

  /// When it was confirmed or ignored; null while still pending. Decides
  /// which handled messages appear in the "recently handled" list for undo.
  /// (Clean-up after [CaptureService.keepHandledFor] goes by [receivedAt].)
  @HiveField(7)
  DateTime? handledAt;

  CapturedSms({
    required this.id,
    required this.dedupeKey,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.status = CaptureStatus.pending,
    List<String>? transactionIds,
    this.handledAt,
  }) : transactionIds = transactionIds ?? [];
}
