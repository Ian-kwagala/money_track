import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/services/balance_history.dart';

final _now = DateTime(2026, 10, 13, 15, 0);

TxRecord _tx(String id, TxType type, double amount, DateTime at, {String wallet = 'w1', String? to}) =>
    TxRecord(id: id, type: type, amount: amount, walletId: wallet, toWalletId: to, dateTime: at);

void main() {
  group('change to the total', () {
    final h = BalanceHistory(currentTotal: 0, transactions: const [], walletIds: {'w1', 'w2'});

    test('income adds, spending subtracts', () {
      expect(h.change(_tx('a', TxType.income, 500, _now)), 500);
      expect(h.change(_tx('b', TxType.expense, 200, _now)), -200);
    });

    test('moving money between two of your wallets changes nothing', () {
      expect(h.change(_tx('c', TxType.transfer, 300, _now, wallet: 'w1', to: 'w2')), 0);
    });

    test('money moved to a goal or debt (one-sided) leaves the total', () {
      expect(h.change(_tx('d', TxType.transfer, 300, _now, wallet: 'w1')), -300);
      expect(h.change(_tx('e', TxType.transfer, 300, _now, wallet: '', to: 'w2')), 300);
    });

    test('a transaction on a wallet that no longer exists does not count', () {
      expect(h.change(_tx('f', TxType.income, 500, _now, wallet: 'gone')), 0);
      expect(h.change(_tx('g', TxType.transfer, 300, _now, wallet: 'gone', to: 'w1')), 300);
    });

    test('with no wallets at all, it is just income minus spending', () {
      final noWallets = BalanceHistory(currentTotal: 0, transactions: const []);
      expect(noWallets.change(_tx('h', TxType.expense, 80, _now)), -80);
      expect(noWallets.change(_tx('i', TxType.transfer, 80, _now, to: 'w2')), 0);
    });
  });

  test('the total in the past is today\'s total minus what happened since', () {
    final h = BalanceHistory(
      currentTotal: 100000,
      walletIds: {'w1'},
      transactions: [
        _tx('a', TxType.income, 50000, DateTime(2026, 10, 10)),
        _tx('b', TxType.expense, 20000, DateTime(2026, 10, 12)),
      ],
    );
    expect(h.totalAt(_now), 100000);
    expect(h.totalAt(DateTime(2026, 10, 11)), 120000); // before the expense
    expect(h.totalAt(DateTime(2026, 10, 9)), 70000); // before the income too
  });

  group('balanceTrend', () {
    // Earning 10,000 every day for the last year.
    final daily = [
      for (var i = 0; i < 400; i++) _tx('d$i', TxType.income, 10000, DateTime(2026, 10, 13, 9).subtract(Duration(days: i))),
    ];
    final h = BalanceHistory(currentTotal: 5000000, walletIds: {'w1'}, transactions: daily);

    test('week: one point per day, ending now, labelled by weekday', () {
      final points = balanceTrend(h, TrendRange.week, _now);
      expect(points, hasLength(7));
      expect(points.last.at, _now);
      expect(points.last.label, 'Tue'); // 13 Oct 2026
      expect(points.first.label, 'Wed');
    });

    test('month: the last 30 days', () {
      final points = balanceTrend(h, TrendRange.month, _now);
      expect(points, hasLength(30));
      expect(points.first.label, '14'); // 14 Sep
      expect(points.last.label, '13');
    });

    test('year: one point per month, labelled by month', () {
      final points = balanceTrend(h, TrendRange.year, _now);
      expect(points, hasLength(12));
      expect(points.first.label, 'Nov');
      expect(points.last.label, 'Oct');
      expect(points[10].at, DateTime(2026, 10, 1), reason: 'end of September');
    });

    test('a growing balance makes a rising line', () {
      for (final range in TrendRange.values) {
        final totals = [for (final p in balanceTrend(h, range, _now)) p.total];
        for (var i = 1; i < totals.length; i++) {
          expect(totals[i], greaterThan(totals[i - 1]), reason: '$range point $i');
        }
        expect(totals.last, 5000000);
      }
    });
  });

  group('niceAxis', () {
    test('fits the values with round gridlines', () {
      final a = niceAxis([1230000, 1480000, 1720000]);
      expect(a.min, lessThanOrEqualTo(1230000));
      expect(a.max, greaterThanOrEqualTo(1720000));
      expect(a.interval, 200000);
      expect(a.min % a.interval, 0);
      expect(a.max % a.interval, 0);
    });

    test('zooms in on the values instead of starting at zero', () {
      final a = niceAxis([1230000, 1250000]);
      expect(a.min, greaterThan(1000000));
      expect((a.max - a.min) / a.interval, lessThanOrEqualTo(6));
    });

    test('scales to large amounts with round steps', () {
      final a = niceAxis([2000000, 48000000]);
      expect(a.min, 0);
      expect(a.max, greaterThanOrEqualTo(48000000));
      expect(a.interval, 20000000);
      final lines = (a.max - a.min) / a.interval;
      expect(lines, inInclusiveRange(2, 6));
    });

    test('handles negative balances', () {
      final a = niceAxis([-35000, 12000]);
      expect(a.min, lessThanOrEqualTo(-35000));
      expect(a.max, greaterThanOrEqualTo(12000));
    });

    test('a flat line sits mid-chart, and all-zero still has a range', () {
      final flat = niceAxis([400000, 400000]);
      expect(flat.min, lessThan(400000));
      expect(flat.max, greaterThan(400000));
      final zero = niceAxis([0, 0, 0]);
      expect(zero.min, lessThan(0));
      expect(zero.max, greaterThan(0));
    });

    test('the line never runs along the very top', () {
      final a = niceAxis([0, 100000]);
      expect(a.max, greaterThan(100000));
    });
  });
}
