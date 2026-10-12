import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/data/seed_data.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/models/wallet.dart';
import 'package:money_track/services/capture/capture_suggestions.dart';
import 'package:money_track/services/capture/money_message.dart';
import 'package:money_track/services/capture/money_message_parser.dart';

const _parser = MoneyMessageParser();
final _at = DateTime(2026, 10, 5, 7, 0);

ParsedMoneyMessage _read(String sms) => _parser.parse(sms, receivedAt: _at)!;

CaptureSuggestions _with({List<Wallet> extraWallets = const [], Map<String, String> memory = const {}}) =>
    CaptureSuggestions(
      wallets: [...SeedData.wallets(), ...extraWallets],
      categories: [...SeedData.expenseCategories(), ...SeedData.incomeCategories()],
      memory: memory,
    );

Wallet _wallet(String id, String name, WalletType type) => Wallet(id: id, name: name, type: type);

const _airtelSent = 'SENT UGX 21,000 to GRACE AKELLO on 256700345. Fee UGX 500.0 Bal UGX 11,450. TID 157700004.';
const _airtelDeposit = 'Cash deposit of UGX 31,200 from CENTENARY BANK. Balance UGX 33,675. '
    'Trans ID:158000003. Date 05-October-2026 06:15.';
const _mtnToMoKash = 'You have transferred 6067.00 UGX to MoKash . (2567000999) from your mobile money '
    'account 100200 at 2026-08-06 12:00:52. Your new balance: 0.82 UGX. Financial Transaction Id: 42500000006.';
const _nssfInterest = 'Dear JOHN OKELLO MUGISHA, your Smartlife account - SL10000000001, has been '
    'credited with UGX.116 interest for 2026-09. New Balance: UGX.10331. A Better Life.';
const _centenaryCard = 'Centenary: Dear JOHN MUGISHA, your card trxn of UGX 4,200 on A/C **123 has been '
    'registered on 2026-09-26 at 14:02 now pending settlement. Available balance: UGX 3,155.';

String _paidTo(String name) => 'PAID UGX 5,000 to $name Charge UGX 0, TID 1580700099. Bal UGX 2,675';

void main() {
  group('wallet', () {
    test('each provider lands in its own wallet', () {
      final s = _with();
      expect(s.walletFor(MoneyProvider.mtnMomo), 'wallet_mtn');
      expect(s.walletFor(MoneyProvider.airtelMoney), 'wallet_airtel');
      expect(s.walletFor(MoneyProvider.centenary), 'wallet_bank');
      expect(s.walletFor(MoneyProvider.nssfSmartlife), isNull, reason: 'no savings wallet yet: ask');
    });

    test('a wallet named after the provider wins over the generic one', () {
      final s = _with(extraWallets: [_wallet('w_cente', 'Centenary Savings', WalletType.bank)]);
      expect(s.walletFor(MoneyProvider.centenary), 'w_cente');
    });

    test('NSSF goes to a savings wallet once there is one', () {
      final s = _with(extraWallets: [_wallet('w_save', 'My savings', WalletType.savings)]);
      expect(s.walletFor(MoneyProvider.nssfSmartlife), 'w_save');
    });

    test('the last wallet chosen for a provider is remembered', () {
      final s = _with(memory: {'wallet:airtelMoney': 'wallet_cash'});
      expect(s.walletFor(MoneyProvider.airtelMoney), 'wallet_cash');
    });

    test('a remembered wallet that was deleted is ignored', () {
      final s = _with(memory: {'wallet:airtelMoney': 'gone'});
      expect(s.walletFor(MoneyProvider.airtelMoney), 'wallet_airtel');
    });
  });

  group('type', () {
    test('money sent to a person is an expense from the provider wallet', () {
      final d = _with().draftFor(_read(_airtelSent), fallbackTime: _at);
      expect(d.type, TxType.expense);
      expect(d.walletId, 'wallet_airtel');
      expect(d.amount, 21000);
      expect(d.fee, 500);
      expect(d.note, 'Grace Akello');
      expect(d.dateTime, _at);
      expect(d.categoryId, isNull, reason: 'nothing to go on for a person');
      expect(d.isComplete, isFalse);
    });

    test('a cash deposit from a bank is a transfer Bank → Airtel', () {
      final d = _with().draftFor(_read(_airtelDeposit), fallbackTime: _at);
      expect(d.type, TxType.transfer);
      expect(d.walletId, 'wallet_bank');
      expect(d.toWalletId, 'wallet_airtel');
      expect(d.dateTime, DateTime(2026, 10, 5, 6, 15));
      expect(d.isComplete, isTrue);
    });

    test('a transfer from a wallet to itself is not ready to save', () {
      final d = _with().draftFor(_read(_airtelDeposit), fallbackTime: _at)..toWalletId = 'wallet_bank';
      expect(d.isComplete, isFalse);
    });

    test('a cash deposit at an agent is a transfer Cash → wallet', () {
      final d = _with().draftFor(
          _read('Cash deposit of UGX 10,000 from NTINDA SHOP. Balance UGX 43,675. Trans ID:158000010.'),
          fallbackTime: _at);
      expect(d.type, TxType.transfer);
      expect(d.walletId, 'wallet_cash');
      expect(d.toWalletId, 'wallet_airtel');
    });

    test('a withdrawal is a transfer to Cash', () {
      final d = _with().draftFor(_read('WITHDRAWN UGX 100,000. Fee UGX 2,500 Tax UGX 500. Bal UGX 50,000. TID 157700008.'),
          fallbackTime: _at);
      expect(d.type, TxType.transfer);
      expect(d.walletId, 'wallet_airtel');
      expect(d.toWalletId, 'wallet_cash');
      expect(d.fee, 3000);
    });

    test('money sent to one of your own wallets is a transfer', () {
      final mokash = _wallet('w_mokash', 'MoKash savings', WalletType.savings);
      final d = _with(extraWallets: [mokash]).draftFor(_read(_mtnToMoKash), fallbackTime: _at);
      expect(d.type, TxType.transfer);
      expect(d.walletId, 'wallet_mtn');
      expect(d.toWalletId, 'w_mokash');
    });

    test('without such a wallet it is an expense', () {
      final d = _with().draftFor(_read(_mtnToMoKash), fallbackTime: _at);
      expect(d.type, TxType.expense);
      expect(d.walletId, 'wallet_mtn');
    });

    test('a name that only shares a bank\'s name is not the bank', () {
      final d = _with().draftFor(_read(_paidTo('CENTENARY HIGH SCHOOL')), fallbackTime: _at);
      expect(d.type, TxType.expense);
      expect(d.categoryId, 'cat_expense_school_fees');
    });

    test('money sent to a bank account at a known provider is a transfer', () {
      final d = _with().draftFor(_read(_paidTo('CENTENARY BANK')), fallbackTime: _at);
      expect(d.type, TxType.transfer);
      expect(d.walletId, 'wallet_airtel');
      expect(d.toWalletId, 'wallet_bank');
    });

    test('a Cash wallet is never matched by name ("Agent Cash Point" is a shop)', () {
      final d = _with().draftFor(_read(_paidTo('AGENT CASH POINT')), fallbackTime: _at);
      expect(d.type, TxType.expense);
    });

    test('interest is income under Savings', () {
      final save = _wallet('w_save', 'NSSF Smartlife', WalletType.savings);
      final d = _with(extraWallets: [save]).draftFor(_read(_nssfInterest), fallbackTime: _at);
      expect(d.type, TxType.income);
      expect(d.walletId, 'w_save');
      expect(d.categoryId, 'cat_income_savings');
      expect(d.note, 'Interest · NSSF Smartlife');
    });

    test('money received from a person is income under Other', () {
      final d = _with().draftFor(
          _read('RECEIVED UGX 51,000 from 2567000102,JANE NAMUKASA,1234. Balance UGX 51,675. TID:1581400001.'),
          fallbackTime: _at);
      expect(d.type, TxType.income);
      expect(d.categoryId, 'cat_income_other');
      expect(d.isComplete, isTrue);
    });

    test('a card payment is an expense from the bank wallet', () {
      final d = _with().draftFor(_read(_centenaryCard), fallbackTime: _at);
      expect(d.type, TxType.expense);
      expect(d.walletId, 'wallet_bank');
      expect(d.note, 'Card payment · Centenary Bank');
    });
  });

  group('category', () {
    final cases = {
      'UMEME LIMITED': 'cat_expense_electricity',
      'NWSC': 'cat_expense_water',
      'SHELL KIRA ROAD': 'cat_expense_fuel',
      'KABAKA FOODS LTD': 'cat_expense_food',
      'CAFE JAVAS': 'cat_expense_meals_out',
      'SAFEBODA': 'cat_expense_transport',
      'KAMPALA PARENTS SCHOOL': 'cat_expense_school_fees',
      'CITY PHARMACY': 'cat_expense_health',
      'DSTV UGANDA': 'cat_expense_entertainment',
    };
    cases.forEach((name, category) {
      test(name, () {
        final d = _with().draftFor(_read(_paidTo(name)), fallbackTime: _at);
        expect(d.categoryId, category);
      });
    });

    test('what you chose for someone before wins over keywords', () {
      final key = CaptureSuggestions.categoryMemoryKey('Kabaka Foods Ltd')!;
      final d = _with(memory: {key: 'cat_expense_meals_out'}).draftFor(_read(_paidTo('KABAKA FOODS LTD')), fallbackTime: _at);
      expect(d.categoryId, 'cat_expense_meals_out');
    });

    test('memory keys ignore case and punctuation', () {
      expect(CaptureSuggestions.categoryMemoryKey('Grace  Akello.'), CaptureSuggestions.categoryMemoryKey('GRACE AKELLO'));
      expect(CaptureSuggestions.categoryMemoryKey(null), isNull);
    });
  });
}
