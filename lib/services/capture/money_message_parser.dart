import 'dart:math' as math;

import 'money_message.dart';

/// Reads Ugandan mobile-money and bank SMS (MTN MoMo, Airtel Money,
/// Centenary Bank, NSSF Smartlife) into [ParsedMoneyMessage]s.
///
/// Instead of one regex per exact message template, it reads a message in
/// independent steps (who sent it, what kind of movement, the amount, fee,
/// balance, transaction ID, date, counterparty), so a provider rewording or
/// reordering a message usually still parses.
///
/// Pure Dart with no plugins, so fixes ship as Shorebird patches. Every
/// format it knows comes from a real message in
/// test/capture/money_message_parser_test.dart — when a message is read
/// wrong, add it there first, then fix the rule.
class MoneyMessageParser {
  const MoneyMessageParser();

  /// Returns null for anything that isn't a completed money movement from a
  /// provider listed in [MoneyProvider]: personal SMS, OTPs, promos, failed
  /// transactions, payment requests.
  ///
  /// [sender] is the SMS sender ID when known (null for pasted text).
  /// Messages from ordinary phone numbers are always ignored, so a person
  /// can't fake a "RECEIVED UGX…" text into someone's records.
  /// [receivedAt] is used when the message itself carries no date.
  ParsedMoneyMessage? parse(String body, {String? sender, DateTime? receivedAt}) {
    final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    if (sender != null && isPersonalNumber(sender)) return null;
    if (_notACompletedTransaction.hasMatch(text)) return null;

    final provider = providerForSender(sender) ?? _providerFromText(text);
    if (provider == null) return null;
    final kind = _kindOf(text);
    if (kind == null) return null;
    if (kind == MoneyMessageKind.received && _airtimeOrBundle.hasMatch(text)) return null;

    double? amount;
    int amountEnd = 0;
    var fee = 0.0;
    double? balance;
    for (final m in _money.allMatches(text)) {
      final value = _numberIn(m);
      if (value == null) continue;
      final before = text.substring(math.max(0, m.start - 30), m.start);
      if (_feeLabelBefore.hasMatch(before)) {
        fee += value;
      } else if (_balanceLabelBefore.hasMatch(before)) {
        balance ??= value;
      } else if (amount == null) {
        amount = value;
        amountEnd = m.end;
      }
    }
    if (amount == null || amount <= 0) return null;

    final party = _counterparty(kind, text.substring(amountEnd));

    return ParsedMoneyMessage(
      provider: provider,
      kind: kind,
      amount: amount,
      fee: fee,
      counterparty: party.name,
      counterpartyNumber: party.number,
      reference: _reference(text),
      balance: balance,
      occurredAt: _occurredAt(text, receivedAt),
      account: _account.firstMatch(text)?.group(1),
      pending: _pending.hasMatch(text),
    );
  }

  /// True for a sender ID that is an ordinary phone number. Providers send
  /// from names ("AirtelMoney") or short codes ("165"), never from a
  /// personal number.
  static bool isPersonalNumber(String sender) =>
      RegExp(r'^\+?\d{9,}$').hasMatch(sender.replaceAll(RegExp(r'[\s\-()]'), ''));

  /// The provider behind an SMS sender ID, or null if it isn't one we know.
  static MoneyProvider? providerForSender(String? sender) {
    if (sender == null) return null;
    final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (s.contains('airtel')) return MoneyProvider.airtelMoney;
    if (s.contains('mtn') || s.contains('momo') || s.contains('mobilemoney')) {
      return MoneyProvider.mtnMomo;
    }
    if (s.contains('centenary') || s.startsWith('cente')) return MoneyProvider.centenary;
    if (s.contains('nssf') || s.contains('smartlife')) return MoneyProvider.nssfSmartlife;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Provider and kind
  // ---------------------------------------------------------------------------

  /// For pasted text, where there's no sender ID: each provider's own
  /// wording. Checked in order, so "Cash deposit … from CENTENARY BANK"
  /// (an Airtel message) isn't taken for a Centenary one.
  static final _providerFingerprints = <(RegExp, MoneyProvider)>[
    (RegExp(r'\bsmartlife\b|\bNSSF\b', caseSensitive: false), MoneyProvider.nssfSmartlife),
    (RegExp(r'^Cente(?:nary)?\b', caseSensitive: false), MoneyProvider.centenary),
    (
      RegExp(r'Financial Transaction Id|\bmobile money account\b|\bMoKash\b', caseSensitive: false),
      MoneyProvider.mtnMomo,
    ),
    (RegExp(r'^(?:RECEIVED|SENT|PAID|WITHDRAWN)\b|\bTID\b|\bTrans ID\b'), MoneyProvider.airtelMoney),
    (RegExp(r'\bairtel\b', caseSensitive: false), MoneyProvider.airtelMoney),
    (RegExp(r'\bMTN\b|\bMoMo\b'), MoneyProvider.mtnMomo),
  ];

  static MoneyProvider? _providerFromText(String text) {
    for (final (pattern, provider) in _providerFingerprints) {
      if (pattern.hasMatch(text)) return provider;
    }
    return null;
  }

  /// Most specific first: a message's opening verb ("RECEIVED", "You have
  /// transferred") beats a phrase that can appear anywhere ("deposit of").
  static final _kinds = <(RegExp, MoneyMessageKind)>[
    (RegExp(r'^RECEIVED\b', caseSensitive: false), MoneyMessageKind.received),
    (RegExp(r'^SENT\b', caseSensitive: false), MoneyMessageKind.sent),
    (RegExp(r'^PAID\b', caseSensitive: false), MoneyMessageKind.payment),
    (RegExp(r'^(?:WITHDRAWN|WITHDRAW|CASH ?OUT)\b', caseSensitive: false), MoneyMessageKind.withdrawal),
    (RegExp(r'^(?:CASH ?IN|DEPOSIT(?:ED)?)\b', caseSensitive: false), MoneyMessageKind.deposit),
    (RegExp(r'\byou have received\b', caseSensitive: false), MoneyMessageKind.received),
    (RegExp(r'\byou have (?:sent|transferred)\b', caseSensitive: false), MoneyMessageKind.sent),
    (RegExp(r'\byou have (?:paid|bought|purchased)\b', caseSensitive: false), MoneyMessageKind.payment),
    (RegExp(r'\byou have withdrawn\b', caseSensitive: false), MoneyMessageKind.withdrawal),
    (RegExp(r'\bcredited with .{0,40}?\binterest\b|\binterest\b.{0,40}\bcredited\b', caseSensitive: false),
        MoneyMessageKind.interest),
    (RegExp(r'\bcard (?:trxn|txn|transaction|purchase|payment)\b', caseSensitive: false),
        MoneyMessageKind.cardPayment),
    (RegExp(r'\bdeposit of\b', caseSensitive: false), MoneyMessageKind.deposit),
    (RegExp(r'\bwithdrawal of\b', caseSensitive: false), MoneyMessageKind.withdrawal),
    (RegExp(r'\b(?:has been|was) credited\b|\bcredited with\b', caseSensitive: false), MoneyMessageKind.deposit),
    (RegExp(r'\b(?:has been|was) debited\b|\bdebited with\b', caseSensitive: false), MoneyMessageKind.payment),
  ];

  static MoneyMessageKind? _kindOf(String text) {
    for (final (pattern, kind) in _kinds) {
      if (pattern.hasMatch(text)) return kind;
    }
    return null;
  }

  static final _notACompletedTransaction = RegExp(
    r'\b(?:OTP|one[- ]time (?:pin|password|code)|verification code|failed|unsuccessful|'
    r'not successful|insufficient|declined|cancell?ed|is requesting|has requested|'
    r'payment request|to approve)\b',
    caseSensitive: false,
  );
  static final _airtimeOrBundle = RegExp(r'\b(?:airtime|bundle|data bonus)\b', caseSensitive: false);
  static final _pending = RegExp(r'\bpending\b', caseSensitive: false);

  // ---------------------------------------------------------------------------
  // Amounts
  // ---------------------------------------------------------------------------

  // 51,000 · 500.0 · 6067.00 · 10331
  static const _num = r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)';
  static const _currency = r'(?:UGX|USHS?|SHS)';

  /// "UGX 51,000", "UGX.116", "6067.00 UGX".
  static final _money = RegExp(
    '\\b$_currency\\.?\\s?$_num|(?<![\\d,.])$_num\\s?$_currency\\b',
    caseSensitive: false,
  );

  static const _feeLabels = r'(?:fees?|charges?|tax|levy|commission)';
  static const _balanceLabels = r'(?:bal|balance)';
  static final _feeLabelBefore = RegExp('\\b$_feeLabels\\b[^\\d]{0,15}\$', caseSensitive: false);
  static final _balanceLabelBefore = RegExp('\\b$_balanceLabels\\b[^\\d]{0,15}\$', caseSensitive: false);

  static double? _numberIn(Match m) {
    for (var i = 1; i <= m.groupCount; i++) {
      final g = m.group(i);
      if (g != null) return double.tryParse(g.replaceAll(',', ''));
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Reference, account, date
  // ---------------------------------------------------------------------------

  static final _referencePattern = RegExp(
    r'\b(?:Financial Transaction Id|Transaction Id|Trans(?:action)?\.? ?ID|TXN ?ID|TID|Ref(?:erence)?(?: No\.?)?)'
    r'\s*[:#.]?\s*([A-Z0-9][A-Z0-9-]{4,})',
    caseSensitive: false,
  );

  static String? _reference(String text) {
    for (final m in _referencePattern.allMatches(text)) {
      final id = m.group(1)!;
      if (RegExp(r'\d').hasMatch(id)) return id;
    }
    return null;
  }

  /// "A/C **095", "account - SL10149049176", "mobile money account 170094".
  static final _account = RegExp(
    r'\b(?:A/C|account)(?: (?:no|number)\.?)?\s*[-:#]?\s*(\*+\d{2,}|[A-Z]{0,4}\d{3,})\b',
    caseSensitive: false,
  );

  static const _time = r'(?:,?\s+(?:at\s+)?(\d{1,2}):(\d{2})(?::(\d{2}))?)?';

  /// "05-October-2026 06:38", "2026-08-06 12:00:52", "2026-09-26 at 14:02",
  /// "26/09/2026 14:02" (day first, as Ugandan providers write it).
  static final _datePatterns = <(RegExp, DateTime? Function(Match))>[
    (
      RegExp('\\b(\\d{1,2})[-\\s]([A-Za-z]{3,9})[-\\s,]+(\\d{4}|\\d{2})\\b$_time'),
      (m) => _date(m[3], _month(m[2]!), m[1], m),
    ),
    (
      RegExp('\\b(\\d{4})-(\\d{2})-(\\d{2})\\b$_time'),
      (m) => _date(m[1], int.parse(m[2]!), m[3], m),
    ),
    (
      RegExp('\\b(\\d{1,2})/(\\d{1,2})/(\\d{4}|\\d{2})\\b$_time'),
      (m) => _date(m[3], int.parse(m[2]!), m[1], m),
    ),
  ];

  static const _months = [
    'january', 'february', 'march', 'april', 'may', 'june', //
    'july', 'august', 'september', 'october', 'november', 'december',
  ];

  static int _month(String name) {
    final n = name.toLowerCase();
    return _months.indexWhere((full) => full.startsWith(n) && n.length >= 3) + 1;
  }

  static DateTime? _date(String? year, int month, String? day, Match m) {
    var y = int.parse(year!);
    if (y < 100) y += 2000;
    final d = int.parse(day!);
    final h = m[4] == null ? 0 : int.parse(m[4]!);
    final min = m[5] == null ? 0 : int.parse(m[5]!);
    final s = m[6] == null ? 0 : int.parse(m[6]!);
    if (month < 1 || month > 12 || d < 1 || d > 31 || h > 23 || min > 59 || s > 59) return null;
    final date = DateTime(y, month, d, h, min, s);
    // DateTime rolls 31 June over to 1 July; that's not a real date.
    return date.month == month ? date : null;
  }

  static DateTime? _occurredAt(String text, DateTime? receivedAt) {
    Match? earliest;
    DateTime? found;
    for (final (pattern, read) in _datePatterns) {
      for (final m in pattern.allMatches(text)) {
        if (earliest != null && m.start >= earliest.start) break;
        final date = read(m);
        if (date == null) continue;
        earliest = m;
        found = date;
        break;
      }
    }
    if (found == null) return receivedAt;
    // A date a day or more after the SMS arrived was misread, not real.
    if (receivedAt != null && found.isAfter(receivedAt.add(const Duration(days: 1)))) {
      return receivedAt;
    }
    return found;
  }

  // ---------------------------------------------------------------------------
  // Counterparty
  // ---------------------------------------------------------------------------

  /// Where the counterparty's name is introduced, per kind. Searched only in
  /// the text after the amount.
  static final _partyIntro = <MoneyMessageKind, RegExp>{
    MoneyMessageKind.received: RegExp(r'\bfrom\s+', caseSensitive: false),
    MoneyMessageKind.deposit: RegExp(r'\bfrom\s+', caseSensitive: false),
    MoneyMessageKind.sent: RegExp(r'\bto\s+', caseSensitive: false),
    MoneyMessageKind.payment: RegExp(r'\b(?:to|for)\s+', caseSensitive: false),
    MoneyMessageKind.withdrawal: RegExp(
        r'\b(?:(?:at|from|through)\s+)?agent\s*(?:no\.?|code)?\s*:?\s*|\b(?:at|from)\s+(?!\d|agent\b)',
        caseSensitive: false),
    MoneyMessageKind.cardPayment: RegExp(r'\b(?:at|to)\s+(?!\d)', caseSensitive: false),
  };

  /// The name runs until a sentence end, a bracket, or the next field.
  static final _partyText = RegExp(
    r'^([^.(]+?)(?=\s*[.(]|\s*$|\s+(?:Charge|Fee|Tax|Bal|Balance|TID|Trans|via|Reason|Ref)\b|'
    r'\s+(?:on|at)\s+\+?\d|,\s*(?:TID|Trans|Fee|Charge|Bal)\b)',
    caseSensitive: false,
  );
  static final _numberAfterParty = RegExp(r'^\s*(?:\.\s*)?\(\s*(\+?\d{9,13})\s*\)|^\s+on\s+(\+?\d{9,13})\b');
  static final _phoneish = RegExp(r'^\+?\d{9,13}$');

  static ({String? name, String? number}) _counterparty(MoneyMessageKind kind, String rest) {
    final intro = _partyIntro[kind];
    if (intro == null) return (name: null, number: null);
    for (final m in intro.allMatches(rest)) {
      final after = rest.substring(m.end);
      final segment = _partyText.firstMatch(after);
      if (segment == null) continue;
      final raw = segment.group(1)!.trim();
      if (raw.isEmpty || raw.toLowerCase().startsWith('your ')) continue;

      String? name;
      String? number;
      for (final token in raw.split(',').map((t) => t.trim())) {
        if (_phoneish.hasMatch(token)) {
          number ??= token;
        } else if (RegExp('[A-Za-z]').hasMatch(token)) {
          name ??= token;
        }
      }
      final trailing = _numberAfterParty.firstMatch(after.substring(segment.end));
      number ??= trailing?.group(1) ?? trailing?.group(2);
      return (name: name == null ? null : tidyName(name), number: number);
    }
    return (name: null, number: null);
  }

  /// Short names that stay upper-case when tidying an all-caps name.
  static const _acronyms = {
    'MTN', 'NSSF', 'NWSC', 'UMEME', 'URA', 'KCCA', 'ATM', 'POS', 'DSTV', 'GOTV',
    'UEDCL', 'ABSA', 'DFCU', 'NCBA', 'KCB', 'UBA', 'AM', 'SACCO', 'UG',
  };

  /// "MATILDA NAKAGOLO" → "Matilda Nakagolo"; mixed-case names are kept.
  static String tidyName(String name) {
    final trimmed = name.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\s,;:-]+$'), '').trim();
    if (RegExp('[a-z]').hasMatch(trimmed)) return trimmed;
    return trimmed.split(' ').map((word) {
      if (_acronyms.contains(word) || RegExp(r'\d').hasMatch(word) || word.length < 2) return word;
      return word[0] + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
