/// What a mobile-money or bank SMS says happened, as read by
/// [MoneyMessageParser]. Nothing here is saved anywhere — it's the parser's
/// output, which the auto-capture review screen turns into a real
/// transaction only after the user confirms it.
library;

/// Who sent the message. Decides which wallet a detection lands in.
enum MoneyProvider {
  mtnMomo('MTN MoMo'),
  airtelMoney('Airtel Money'),
  centenary('Centenary Bank'),
  nssfSmartlife('NSSF Smartlife');

  const MoneyProvider(this.label);

  /// Name shown to the user.
  final String label;
}

/// What kind of money movement the message reports.
enum MoneyMessageKind {
  received('Received', isMoneyIn: true),
  deposit('Deposit', isMoneyIn: true),
  interest('Interest', isMoneyIn: true),
  sent('Sent', isMoneyIn: false),
  payment('Paid', isMoneyIn: false),
  withdrawal('Withdrawn', isMoneyIn: false),
  cardPayment('Card payment', isMoneyIn: false);

  const MoneyMessageKind(this.label, {required this.isMoneyIn});
  final String label;

  /// Whether money arrived in the user's account (income side) rather than
  /// leaving it.
  final bool isMoneyIn;
}

/// The structured details pulled out of one money SMS.
class ParsedMoneyMessage {
  final MoneyProvider provider;
  final MoneyMessageKind kind;

  /// The amount that moved, excluding [fee].
  final double amount;

  /// Total charges on top of [amount] (fee plus any tax). 0 when the message
  /// names none.
  final double fee;

  /// Person or business on the other side, tidied for display
  /// ("MATILDA NAKAGOLO" → "Matilda Nakagolo"). Null when the message names
  /// no one, e.g. a card payment.
  final String? counterparty;

  /// Their phone or account number, when the message includes one.
  final String? counterpartyNumber;

  /// The provider's transaction ID. Used to avoid importing the same
  /// transaction twice.
  final String? reference;

  /// Balance after the transaction, as the provider reports it.
  final double? balance;

  /// When the transaction happened. Taken from the message text when it
  /// carries a date, otherwise from when the SMS arrived; null only if
  /// neither is known.
  final DateTime? occurredAt;

  /// The user's own account the message is about (a masked card or account
  /// number), for telling apart several accounts at the same provider.
  final String? account;

  /// True for card payments the bank has only authorised so far.
  final bool pending;

  const ParsedMoneyMessage({
    required this.provider,
    required this.kind,
    required this.amount,
    this.fee = 0,
    this.counterparty,
    this.counterpartyNumber,
    this.reference,
    this.balance,
    this.occurredAt,
    this.account,
    this.pending = false,
  });

  /// Identifies the underlying transaction, so the same SMS seen twice (or
  /// read once live and again in an inbox scan) is only offered once.
  ///
  /// The provider's transaction ID is the best key. Without one, it falls
  /// back to kind + amount + time to the minute.
  String get dedupeKey {
    if (reference != null) return '${provider.name}:$reference';
    final at = occurredAt;
    final when = at == null
        ? ''
        : '${at.year}-${at.month}-${at.day}T${at.hour}:${at.minute}';
    return '${provider.name}:${kind.name}:${amount.toStringAsFixed(2)}:$when';
  }

  @override
  String toString() => 'ParsedMoneyMessage(${provider.name}, ${kind.name}, '
      'amount: $amount, fee: $fee, counterparty: $counterparty, '
      'number: $counterpartyNumber, ref: $reference, balance: $balance, '
      'at: $occurredAt, account: $account, pending: $pending)';
}
