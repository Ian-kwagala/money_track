import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/bill.dart';
import 'package:money_track/models/budget.dart';
import 'package:money_track/models/frequency.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/ui/format/money_input.dart';

TextEditingValue _type(String text, {int? cursor, String old = ''}) {
  const f = ThousandsSeparatorInputFormatter();
  return f.formatEditUpdate(
    TextEditingValue(text: old, selection: TextSelection.collapsed(offset: old.length)),
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length)),
  );
}

void main() {
  group('ThousandsSeparatorInputFormatter', () {
    test('groups digits with commas', () {
      expect(_type('1234567').text, '1,234,567');
      expect(_type('999').text, '999');
      expect(_type('1000').text, '1,000');
    });

    test('keeps one decimal point and at most 2 decimals', () {
      expect(_type('1234.5').text, '1,234.5');
      expect(_type('1234.567').text, '1,234.56');
      expect(_type('12.3.4').text, '12.34');
      expect(_type('.5').text, '0.5');
    });

    test('drops leading zeros and non-digits', () {
      expect(_type('007').text, '7');
      expect(_type('abc12').text, '12');
      expect(_type('-500').text, '500');
      expect(_type('').text, '');
    });

    test('cursor stays at the end while typing', () {
      final v = _type('1,2345', old: '1,234');
      expect(v.text, '12,345');
      expect(v.selection.end, v.text.length);
    });

    test('backspace over a separator deletes the digit before it', () {
      // "1,|234" -> backspace removes the comma; formatter removes the "1".
      final v = _type('1234', cursor: 1, old: '1,234');
      expect(v.text, '234');
      expect(v.selection.end, 0);
    });
  });

  group('MoneyInput', () {
    test('parse tolerates separators', () {
      expect(MoneyInput.parse('1,250,000.50'), 1250000.5);
      expect(MoneyInput.parse(''), isNull);
    });

    test('text formats prefills', () {
      expect(MoneyInput.text(2500000), '2,500,000');
      expect(MoneyInput.text(1234.5), '1,234.5');
      expect(MoneyInput.text(0), '');
      expect(MoneyInput.text(0, emptyIfZero: false), '0');
    });

    test('group formats keypad digits', () {
      expect(MoneyInput.group('1234567'), '1,234,567');
      expect(MoneyInput.group('0'), '0');
    });
  });

  group('Bill', () {
    test('a paid one-off bill is settled and never overdue', () {
      final bill = Bill(
        id: 'b',
        name: 'Repair',
        amount: 100,
        dueDate: DateTime.now().subtract(const Duration(days: 10)),
        frequency: Frequency.once,
      );
      expect(bill.isOverdue, isTrue);
      expect(bill.isDueWithin(7), isTrue);

      bill.lastPaidDate = DateTime.now();
      expect(bill.isSettled, isTrue);
      expect(bill.isOverdue, isFalse);
      expect(bill.isDueWithin(7), isFalse);
    });

    test('paying a monthly bill moves it to next cycle', () {
      final bill = Bill(id: 'b', name: 'Rent', amount: 100, dueDate: DateTime.now());
      bill.lastPaidDate = DateTime.now();
      expect(bill.isSettled, isFalse);
      expect(bill.isDueWithin(7), isFalse);
      expect(bill.isDueWithin(31), isTrue);
    });

    test('paused bills are never due', () {
      final bill = Bill(id: 'b', name: 'Gym', amount: 100, dueDate: DateTime.now(), isPaused: true);
      expect(bill.isDueWithin(7), isFalse);
      expect(bill.monthlyEquivalent, 0);
    });

    test('monthly equivalent scales by frequency', () {
      expect(Bill(id: 'b', name: 'x', amount: 7000, dueDate: DateTime.now(), frequency: Frequency.weekly).monthlyEquivalent, 30000);
      expect(Bill(id: 'b', name: 'x', amount: 500, dueDate: DateTime.now(), frequency: Frequency.monthly).monthlyEquivalent, 500);
      expect(Bill(id: 'b', name: 'x', amount: 500, dueDate: DateTime.now(), frequency: Frequency.once).monthlyEquivalent, 0);
    });
  });

  test('Budget monthly equivalent scales daily/weekly limits', () {
    Budget b(Frequency f) => Budget(id: 'b', categoryId: 'c', amount: 1000, periodStart: DateTime.now(), frequency: f);
    expect(b(Frequency.daily).monthlyEquivalent, 30000);
    expect(b(Frequency.weekly).monthlyEquivalent, closeTo(4285.7, 0.1));
    expect(b(Frequency.monthly).monthlyEquivalent, 1000);
  });

  test('one-sided transfers report direction and wallet', () {
    final out = TxRecord(id: '1', type: TxType.transfer, amount: 10, walletId: 'w1', dateTime: DateTime.now(), linkId: 'goal:g');
    final into = TxRecord(id: '2', type: TxType.transfer, amount: 10, walletId: '', toWalletId: 'w2', dateTime: DateTime.now());
    final normal = TxRecord(id: '3', type: TxType.transfer, amount: 10, walletId: 'w1', toWalletId: 'w2', dateTime: DateTime.now());

    expect(out.isOneSided, isTrue);
    expect(out.isOneSidedIn, isFalse);
    expect(out.oneSidedWalletId, 'w1');
    expect(into.isOneSidedIn, isTrue);
    expect(into.oneSidedWalletId, 'w2');
    expect(normal.isOneSided, isFalse);
    // Never counts as income or spending.
    expect(out.signedAmount, 0);
  });
}
