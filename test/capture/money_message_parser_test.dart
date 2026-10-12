import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/services/capture/money_message.dart';
import 'package:money_track/services/capture/money_message_parser.dart';

const _parser = MoneyMessageParser();

/// Real messages received in Uganda, copied exactly. Only names, phone,
/// account and transaction numbers were changed (same length and layout),
/// so the format the parser has to read is the real one.
const _airtelReceived =
    'RECEIVED UGX 51,000 from 2567000102,JANE NAMUKASA,1234. Balance UGX 51,675. TID:1581400001.';
const _airtelPaid = 'PAID UGX 31,000 to AM Global Pay Charge UGX 0, TID 1580700002. '
    'Bal UGX 2,675 Date: 05-October-2026 06:38. https://bit.ly/3AbcDeF';
const _airtelDeposit = 'Cash deposit of UGX 31,200 from CENTENARY BANK. Balance UGX 33,675. '
    'Trans ID:158000003. Date 05-October-2026 06:15.';
const _airtelSent =
    'SENT UGX 21,000 to GRACE AKELLO on 256700345. Fee UGX 500.0 Bal UGX 11,450. TID 157700004.';
const _nssfInterest = 'Dear JOHN OKELLO MUGISHA, your Smartlife account - SL10000000001, has been '
    'credited with UGX.116 interest for 2026-09. New Balance: UGX.10331. A Better Life.';
const _centenaryCard = 'Centenary: Dear JOHN MUGISHA, your card trxn of UGX 4,200  on A/C **123  has '
    'been registered on 2026-09-26 at 14:02 now pending settlement. Available balance: UGX 3,155. '
    'For inquiries, call our toll free lines 0800200555/0800335344';
const _mtnTransfer = 'You have transferred 6067.00 UGX to MoKash . (2567000999) from your mobile money '
    'account 100200 at 2026-08-06 12:00:52. Your new balance: 0.82 UGX. Message from sender: Auto '
    'Debit Request. Message to receiver: 20260806000005. Financial Transaction Id: 42500000006.';

final _arrived = DateTime(2026, 10, 5, 7, 0);

void main() {
  group('real messages', () {
    test('Airtel: money received', () {
      final m = _parser.parse(_airtelReceived, receivedAt: _arrived)!;
      expect(m.provider, MoneyProvider.airtelMoney);
      expect(m.kind, MoneyMessageKind.received);
      expect(m.amount, 51000);
      expect(m.fee, 0);
      expect(m.counterparty, 'Jane Namukasa');
      expect(m.counterpartyNumber, '2567000102');
      expect(m.balance, 51675);
      expect(m.reference, '1581400001');
      expect(m.occurredAt, _arrived, reason: 'no date in the message, so when it arrived');
      expect(m.pending, isFalse);
    });

    test('Airtel: merchant payment', () {
      final m = _parser.parse(_airtelPaid)!;
      expect(m.provider, MoneyProvider.airtelMoney);
      expect(m.kind, MoneyMessageKind.payment);
      expect(m.amount, 31000);
      expect(m.fee, 0);
      expect(m.counterparty, 'AM Global Pay');
      expect(m.counterpartyNumber, isNull);
      expect(m.balance, 2675);
      expect(m.reference, '1580700002');
      expect(m.occurredAt, DateTime(2026, 10, 5, 6, 38));
    });

    test('Airtel: cash deposit from a bank', () {
      final m = _parser.parse(_airtelDeposit)!;
      expect(m.provider, MoneyProvider.airtelMoney);
      expect(m.kind, MoneyMessageKind.deposit);
      expect(m.amount, 31200);
      expect(m.counterparty, 'Centenary Bank');
      expect(m.balance, 33675);
      expect(m.reference, '158000003');
      expect(m.occurredAt, DateTime(2026, 10, 5, 6, 15));
    });

    test('Airtel: money sent, with a fee', () {
      final m = _parser.parse(_airtelSent)!;
      expect(m.provider, MoneyProvider.airtelMoney);
      expect(m.kind, MoneyMessageKind.sent);
      expect(m.amount, 21000);
      expect(m.fee, 500);
      expect(m.counterparty, 'Grace Akello');
      expect(m.counterpartyNumber, '256700345');
      expect(m.balance, 11450);
      expect(m.reference, '157700004');
    });

    test('NSSF Smartlife: monthly interest', () {
      final m = _parser.parse(_nssfInterest, receivedAt: _arrived)!;
      expect(m.provider, MoneyProvider.nssfSmartlife);
      expect(m.kind, MoneyMessageKind.interest);
      expect(m.kind.isMoneyIn, isTrue);
      expect(m.amount, 116);
      expect(m.balance, 10331);
      expect(m.account, 'SL10000000001');
      expect(m.counterparty, isNull);
      expect(m.reference, isNull);
      expect(m.occurredAt, _arrived, reason: '"for 2026-09" is the period, not a date');
    });

    test('Centenary: card payment pending settlement', () {
      final m = _parser.parse(_centenaryCard)!;
      expect(m.provider, MoneyProvider.centenary);
      expect(m.kind, MoneyMessageKind.cardPayment);
      expect(m.kind.isMoneyIn, isFalse);
      expect(m.amount, 4200);
      expect(m.balance, 3155);
      expect(m.account, '**123');
      expect(m.pending, isTrue);
      expect(m.counterparty, isNull, reason: 'the bank does not name the shop');
      expect(m.occurredAt, DateTime(2026, 9, 26, 14, 2));
    });

    test('MTN MoMo: transfer to MoKash', () {
      final m = _parser.parse(_mtnTransfer)!;
      expect(m.provider, MoneyProvider.mtnMomo);
      expect(m.kind, MoneyMessageKind.sent);
      expect(m.amount, 6067);
      expect(m.fee, 0);
      expect(m.counterparty, 'MoKash');
      expect(m.counterpartyNumber, '2567000999');
      expect(m.balance, 0.82);
      expect(m.reference, '42500000006');
      expect(m.account, '100200');
      expect(m.occurredAt, DateTime(2026, 8, 6, 12, 0, 52));
    });

    test('line breaks and extra spaces do not change the result', () {
      final messy = _airtelSent.replaceAll('. ', '.\n\n  ').replaceAll(' to ', '   to\n');
      expect(_parser.parse(messy).toString(), _parser.parse(_airtelSent).toString());
    });
  });

  group('sender ID', () {
    test('a known sender decides the provider', () {
      // The deposit mentions CENTENARY BANK, but Airtel sent it.
      expect(_parser.parse(_airtelDeposit, sender: 'AirtelMoney')!.provider, MoneyProvider.airtelMoney);
      expect(_parser.parse(_mtnTransfer, sender: 'MTNMobMoney')!.provider, MoneyProvider.mtnMomo);
      expect(_parser.parse(_centenaryCard, sender: 'CENTENARY')!.provider, MoneyProvider.centenary);
      expect(_parser.parse(_nssfInterest, sender: 'NSSF_UG')!.provider, MoneyProvider.nssfSmartlife);
    });

    test('a known sender is enough when the text alone names no provider', () {
      final unbranded = _centenaryCard.replaceFirst('Centenary: ', '');
      expect(_parser.parse(unbranded), isNull);
      expect(_parser.parse(unbranded, sender: 'CENTENARY')!.provider, MoneyProvider.centenary);
    });

    test('an unknown name or short code falls back to the message text', () {
      expect(_parser.parse(_airtelSent, sender: 'InfoSMS')!.provider, MoneyProvider.airtelMoney);
      expect(_parser.parse(_mtnTransfer, sender: '165')!.provider, MoneyProvider.mtnMomo);
    });

    test('messages from personal phone numbers are never read', () {
      for (final sender in ['+256772000111', '0772000111', '256 772 000 111', '+256-772-000111']) {
        expect(_parser.parse(_airtelReceived, sender: sender), isNull, reason: sender);
      }
    });

    test('isPersonalNumber', () {
      expect(MoneyMessageParser.isPersonalNumber('+256772000111'), isTrue);
      expect(MoneyMessageParser.isPersonalNumber('AirtelMoney'), isFalse);
      expect(MoneyMessageParser.isPersonalNumber('185'), isFalse);
    });
  });

  group('not transactions', () {
    final ignored = <String, String>{
      'OTP': 'Your OTP is 482913. Do not share it with anyone. Centenary Bank',
      'insufficient funds': 'Transaction failed. You have insufficient funds to send UGX 50,000 to GRACE AKELLO.',
      'payment request': 'JOHN OKELLO is requesting UGX 10,000 from you. Dial *165# to approve.',
      'promo': "Y'ello! Get 1GB for UGX 1,000 valid 24hrs. Dial *157# now. MTN",
      'airtime received': 'You have received airtime of UGX 1,000 from 256772000111. MTN',
      'personal chat': 'Hey, I sent you 20,000 yesterday, check your MoMo',
      'declined card': 'Centenary: Dear JOHN MUGISHA, your card trxn of UGX 120,000 on A/C **123 was '
          'declined due to insufficient funds. Available balance: UGX 3,155.',
      'failed send': 'SENT UGX 21,000 to GRACE AKELLO failed. You have not been charged. TID 157700011.',
      'empty': '   ',
    };
    ignored.forEach((name, body) {
      test(name, () => expect(_parser.parse(body), isNull));
    });
  });

  group('formats assumed from the common layout (replace with real samples)', () {
    test('MTN MoMo: money received', () {
      final m = _parser.parse("Y'ello. You have received UGX 20,000 from JOHN OKELLO (256772000111) on "
          'your mobile money account at 2026-10-01 09:15:00. Message from sender: rent. Your new '
          'balance: UGX 25,000. Financial Transaction Id: 42500000007.')!;
      expect(m.provider, MoneyProvider.mtnMomo);
      expect(m.kind, MoneyMessageKind.received);
      expect(m.amount, 20000);
      expect(m.counterparty, 'John Okello');
      expect(m.counterpartyNumber, '256772000111');
      expect(m.balance, 25000);
      expect(m.reference, '42500000007');
      expect(m.occurredAt, DateTime(2026, 10, 1, 9, 15));
    });

    test('Airtel: withdrawal, fee and tax add up', () {
      final m = _parser.parse('WITHDRAWN UGX 100,000. Fee UGX 2,500 Tax UGX 500. Bal UGX 50,000. '
          'TID 157700008. Date 06-Oct-2026 18:20.')!;
      expect(m.kind, MoneyMessageKind.withdrawal);
      expect(m.amount, 100000);
      expect(m.fee, 3000);
      expect(m.balance, 50000);
      expect(m.occurredAt, DateTime(2026, 10, 6, 18, 20));
    });

    test('MTN MoMo: agent withdrawal', () {
      final m = _parser.parse('You have withdrawn UGX 50,000 from your mobile money account at agent: '
          'NTINDA SHOP (256772000222) at 2026-10-02 17:45:10. Fee was UGX 1,000. Tax was UGX 250. Your '
          'new balance: UGX 5,000. Financial Transaction Id: 42500000014.')!;
      expect(m.kind, MoneyMessageKind.withdrawal);
      expect(m.amount, 50000);
      expect(m.fee, 1250);
      expect(m.counterparty, 'Ntinda Shop');
      expect(m.counterpartyNumber, '256772000222');
      expect(m.balance, 5000);
    });

    test('day-first slash dates', () {
      final m = _parser.parse('Centenary: Your A/C **123 has been debited with UGX 15,000 on 26/09/2026 '
          '14:02. Available balance: UGX 3,155.')!;
      expect(m.kind, MoneyMessageKind.payment);
      expect(m.amount, 15000);
      expect(m.occurredAt, DateTime(2026, 9, 26, 14, 2));
    });
  });

  test('a note starting with "Ref" is not taken for the transaction ID', () {
    final m = _parser.parse('SENT UGX 21,000 to GRACE AKELLO on 256700345. Reason: Reference books. '
        'Fee UGX 500 Bal UGX 11,450. TID 157700012.')!;
    expect(m.reference, '157700012');
  });

  group('dates', () {
    test('a date more than a day after arrival is a misread, so arrival wins', () {
      final m = _parser.parse(_airtelPaid, receivedAt: DateTime(2026, 1, 1))!;
      expect(m.occurredAt, DateTime(2026, 1, 1));
    });

    test('impossible dates are ignored', () {
      final m = _parser.parse('SENT UGX 1,000 to GRACE AKELLO. TID 157700009. Date 31-June-2026 10:00.',
          receivedAt: _arrived)!;
      expect(m.occurredAt, _arrived);
    });
  });

  group('dedupeKey', () {
    test('the same message read twice gives the same key', () {
      expect(_parser.parse(_airtelSent)!.dedupeKey, _parser.parse(_airtelSent, sender: 'AirtelMoney')!.dedupeKey);
    });

    test('uses the transaction ID when there is one', () {
      expect(_parser.parse(_airtelSent)!.dedupeKey, 'airtelMoney:157700004');
    });

    test('without an ID, amount and time tell transactions apart', () {
      final a = _parser.parse(_centenaryCard)!;
      final b = _parser.parse(_centenaryCard.replaceFirst('4,200', '4,300'))!;
      final c = _parser.parse(_centenaryCard.replaceFirst('14:02', '15:40'))!;
      expect({a.dedupeKey, b.dedupeKey, c.dedupeKey}, hasLength(3));
    });
  });

  test('tidyName', () {
    expect(MoneyMessageParser.tidyName('MATILDA NAKAGOLO'), 'Matilda Nakagolo');
    expect(MoneyMessageParser.tidyName('UMEME LIMITED'), 'UMEME Limited');
    expect(MoneyMessageParser.tidyName('AM Global Pay'), 'AM Global Pay');
    expect(MoneyMessageParser.tidyName(' SHELL  KIRA ROAD, '), 'Shell Kira Road');
  });
}
