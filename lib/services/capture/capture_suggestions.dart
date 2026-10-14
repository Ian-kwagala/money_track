import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import 'money_message.dart';
import 'money_message_parser.dart';

/// What confirming a captured SMS would record. [CaptureSuggestions.draftFor]
/// fills it in; the review sheet lets the user change any of it.
class CaptureDraft {
  TxType type;

  /// Income: the wallet the money arrives in. Expense and transfer: the
  /// wallet it leaves.
  String? walletId;

  /// Transfers only: the wallet the money arrives in.
  String? toWalletId;

  /// Income and expense only; transfers have none.
  String? categoryId;

  double amount;

  /// Recorded as its own expense in [CaptureSuggestions.feesCategoryId], so
  /// the main amount matches the SMS and charges are visible in reports.
  double fee;

  String note;
  DateTime dateTime;

  CaptureDraft({
    required this.type,
    required this.walletId,
    this.toWalletId,
    this.categoryId,
    required this.amount,
    this.fee = 0,
    required this.note,
    required this.dateTime,
  });

  /// Everything needed to save it without asking the user.
  bool get isComplete => missing == null;

  /// What still has to be filled in before it can be saved, as the user
  /// would be told it, or null when nothing is missing.
  String? get missing {
    if (amount <= 0) return 'Enter the amount';
    if (fee < 0) return 'The fee can\'t be negative';
    if (walletId == null) return type == TxType.transfer ? 'Choose where the money came from' : 'Choose a wallet';
    if (type == TxType.transfer) {
      if (toWalletId == null) return 'Choose where the money went';
      if (toWalletId == walletId) return 'Pick two different wallets';
      return null;
    }
    return categoryId == null ? 'Pick a category' : null;
  }

  /// An independent copy, so the review sheet can edit freely and discard
  /// the changes on cancel.
  CaptureDraft copy() => CaptureDraft(
        type: type,
        walletId: walletId,
        toWalletId: toWalletId,
        categoryId: categoryId,
        amount: amount,
        fee: fee,
        note: note,
        dateTime: dateTime,
      );
}

/// Picks the wallet, type and category for a captured SMS from the user's
/// own wallets and categories, plus what they chose for the same
/// counterparty before ([memory]).
class CaptureSuggestions {
  final List<Wallet> wallets;
  final List<Category> categories;

  /// `wallet:<provider>[:<account>]` → wallet id and `category:<counterparty>`
  /// → category id, as remembered by [CaptureService] on each confirm.
  final Map<String, String> memory;

  CaptureSuggestions({required this.wallets, required this.categories, this.memory = const {}});

  /// Created on first use by CaptureService when a confirmed SMS has a fee.
  static const feesCategoryId = 'cat_expense_fees_and_charges';

  /// Memory key for a provider's wallet, optionally per account number.
  static String walletMemoryKey(MoneyProvider provider, [String? account]) =>
      account == null ? 'wallet:${provider.name}' : 'wallet:${provider.name}:$account';

  /// Memory key for a counterparty's category, normalised to lower-case
  /// words so "MATILDA N." and "Matilda N" share one entry.
  static String? categoryMemoryKey(String? counterparty) {
    final key = _words(counterparty).join(' ');
    return key.isEmpty ? null : 'category:$key';
  }

  /// The best guess at how to record [m]. Starts as a plain income/expense
  /// on the provider's wallet ("home"), then becomes a transfer when the
  /// money really moved between two of the user's own wallets (cash out at
  /// an agent, a deposit from the bank, sending to their own savings...).
  CaptureDraft draftFor(ParsedMoneyMessage m, {required DateTime fallbackTime}) {
    final home = walletFor(m.provider, m.account);
    // A wallet of the user's that the counterparty names, if any.
    final other = _ownWalletNamed(m.counterparty, exclude: home);
    final draft = CaptureDraft(
      type: m.kind.isMoneyIn ? TxType.income : TxType.expense,
      walletId: home,
      amount: m.amount,
      fee: m.fee,
      note: m.counterparty ?? '${m.kind.label} · ${m.provider.label}',
      dateTime: m.occurredAt ?? fallbackTime,
    );

    void transfer({required String? from, required String? to}) {
      draft
        ..type = TxType.transfer
        ..walletId = from
        ..toWalletId = to;
    }

    switch (m.kind) {
      case MoneyMessageKind.withdrawal:
        // Cash out at an agent: the money is now in your pocket.
        final cash = _cashWallet();
        if (cash != null && cash != home) transfer(from: home, to: cash);
      case MoneyMessageKind.deposit:
        // From a bank, or cash handed to an agent.
        final from = other ?? (_looksLikeBank(m.counterparty) ? _firstOfType(WalletType.bank) : _cashWallet());
        if (from != null && from != home) transfer(from: from, to: home);
      case MoneyMessageKind.received:
        if (other != null) transfer(from: other, to: home);
      case MoneyMessageKind.sent:
      case MoneyMessageKind.payment:
      case MoneyMessageKind.cardPayment:
        if (other != null) transfer(from: home, to: other);
      case MoneyMessageKind.interest:
        break;
    }
    if (draft.type != TxType.transfer) draft.categoryId = categoryFor(m, draft.type);
    return draft;
  }

  // ---------------------------------------------------------------------------
  // Wallets
  // ---------------------------------------------------------------------------

  // How a provider is matched to a wallet, from most to least specific (see
  // [walletFor]): what the user picked before, a wallet whose name contains
  // a hint word, the seeded default wallet, then any wallet of a fitting
  // type.

  static const _defaultWalletIds = {
    MoneyProvider.mtnMomo: 'wallet_mtn',
    MoneyProvider.airtelMoney: 'wallet_airtel',
    MoneyProvider.centenary: 'wallet_bank',
  };

  static const _walletNameHints = {
    MoneyProvider.mtnMomo: ['mtn', 'momo'],
    MoneyProvider.airtelMoney: ['airtel'],
    MoneyProvider.centenary: ['centenary', 'cente'],
    MoneyProvider.nssfSmartlife: ['nssf', 'smartlife'],
  };

  static const _walletTypeHints = {
    MoneyProvider.centenary: WalletType.bank,
    MoneyProvider.nssfSmartlife: WalletType.savings,
  };

  /// The wallet a provider's messages belong to, or null if the user has to
  /// choose (e.g. no savings wallet for NSSF yet).
  String? walletFor(MoneyProvider provider, [String? account]) {
    bool exists(String? id) => id != null && wallets.any((w) => w.id == id);
    for (final key in [if (account != null) walletMemoryKey(provider, account), walletMemoryKey(provider)]) {
      if (exists(memory[key])) return memory[key];
    }
    final hints = _walletNameHints[provider] ?? const [];
    for (final w in wallets) {
      final name = w.name.toLowerCase();
      if (hints.any(name.contains)) return w.id;
    }
    if (exists(_defaultWalletIds[provider])) return _defaultWalletIds[provider];
    final type = _walletTypeHints[provider];
    return type == null ? null : _firstOfType(type);
  }

  /// One of the user's own non-cash wallets whose name matches the
  /// counterparty, e.g. "Centenary Bank" → the "Bank" wallet, or "MoKash" → a
  /// "MoKash savings" wallet. Money going there is a transfer, not spending.
  String? _ownWalletNamed(String? counterparty, {String? exclude}) {
    final party = _words(counterparty).toSet();
    if (party.isEmpty) return null;
    for (final w in wallets) {
      if (w.id == exclude || w.type == WalletType.cash) continue;
      final name = _words(w.name).toSet();
      if (name.isEmpty) continue;
      if (party.containsAll(name) || name.containsAll(party)) return w.id;
    }
    // "Centenary Bank" or "MTN Mobile Money" is an account at a provider;
    // "Centenary High School" is not.
    final provider = MoneyMessageParser.providerForSender(counterparty);
    if (provider == null || !party.any(_accountWords.contains)) return null;
    final id = walletFor(provider);
    return id == exclude ? null : id;
  }

  static const _accountWords = {'bank', 'money', 'momo', 'nssf', 'smartlife'};

  /// The seeded Cash wallet if it still exists, otherwise any cash wallet.
  String? _cashWallet() =>
      wallets.any((w) => w.id == 'wallet_cash') ? 'wallet_cash' : _firstOfType(WalletType.cash);

  String? _firstOfType(WalletType type) {
    for (final w in wallets) {
      if (w.type == type) return w.id;
    }
    return null;
  }

  static bool _looksLikeBank(String? name) => _words(name).contains('bank');

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// Checked in order against the counterparty's name.
  static final _categoryKeywords = <(RegExp, String)>[
    (_kw(r'umeme|uedcl|yaka|electric\w*|power'), 'cat_expense_electricity'),
    (_kw(r'nwsc|water'), 'cat_expense_water'),
    (_kw(r'shell|total\w*|stabex|rubis|hass|gaz|petro\w*|fuel|vivo|oil'), 'cat_expense_fuel'),
    (_kw(r'airtime|bundles?|data|internet|wifi'), 'cat_expense_airtime_and_data'),
    (_kw(r'pharmac\w*|clinic|hospital|medical|health|drug\w*'), 'cat_expense_health'),
    (_kw(r'school|college|university|academy|tuition|fees'), 'cat_expense_school_fees'),
    (_kw(r'rent|landlord'), 'cat_expense_rent'),
    (_kw(r'restaurant|cafe|kitchen|grill|pizza|chicken|javas?'), 'cat_expense_meals_out'),
    (_kw(r'supermarket|foods?|grocer\w*|market|bakery|butcher\w*|mart'), 'cat_expense_food'),
    (_kw(r'safe ?boda|boda|uber|bolt|taxi|faras|bus|transport'), 'cat_expense_transport'),
    (_kw(r'dstv|gotv|startimes|netflix|showmax|cinema|azam'), 'cat_expense_entertainment'),
  ];

  static RegExp _kw(String words) => RegExp('\\b(?:$words)\\b', caseSensitive: false);

  /// The category to suggest: what the user chose for this counterparty
  /// before, else a default for income, else a keyword match on the
  /// counterparty's name. Only returns categories that exist and match
  /// [type]; null means the user has to pick.
  String? categoryFor(ParsedMoneyMessage m, TxType type) {
    bool usable(String? id) => id != null && categories.any((c) => c.id == id && c.type == type);

    final remembered = memory[categoryMemoryKey(m.counterparty)];
    if (usable(remembered)) return remembered;

    if (type == TxType.income) {
      final id = m.kind == MoneyMessageKind.interest ? 'cat_income_savings' : 'cat_income_other';
      return usable(id) ? id : null;
    }
    final name = m.counterparty;
    if (name == null) return null;
    for (final (pattern, id) in _categoryKeywords) {
      if (pattern.hasMatch(name) && usable(id)) return id;
    }
    return null;
  }

  /// Lower-case alphanumeric words, for loose name comparisons.
  static List<String> _words(String? s) => s == null
      ? const []
      : s.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
}
