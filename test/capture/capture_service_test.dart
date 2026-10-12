import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/captured_sms.dart';
import 'package:money_track/models/transaction.dart';
import 'package:money_track/models/wallet.dart';
import 'package:money_track/services/capture/capture_service.dart';
import 'package:money_track/services/capture/capture_suggestions.dart';
import 'package:money_track/services/capture/sms_bridge.dart';

import 'capture_test_helpers.dart';

void main() {
  late Phone phone;

  setUp(() async {
    Phone.now = DateTime(2026, 10, 12, 9, 0);
    phone = await Phone.boot();
  });
  tearDown(() => phone.shutdown());

  group('turning on', () {
    test('imports the last 30 days of money SMS and nothing else', () async {
      phone.bridge.inbox.addAll([
        sms(airtelSent),
        sms(promo, sender: 'MTN'),
        sms(nssfInterest, sender: 'NSSF', at: DateTime(2026, 10, 1)),
        sms(airtelReceived, at: DateTime(2026, 8, 1)), // older than 30 days
      ]);

      expect(await phone.capture.turnOn(), TurnOnResult.on);

      expect(phone.capture.isOn, isTrue);
      expect(phone.bridge.listening, isTrue);
      expect(phone.bridge.askedToNotify, isTrue);
      expect(phone.bridge.inboxReadsSince.single, Phone.now.subtract(const Duration(days: 30)));
      expect(phone.capture.pending.map((c) => c.message.amount), [21000, 116], reason: 'newest first');
    });

    test('a refusal leaves it off and says whether Android will ask again', () async {
      phone.bridge.answer = SmsAccess.denied;
      expect(await phone.capture.turnOn(), TurnOnResult.denied);
      phone.bridge.answer = SmsAccess.blocked;
      expect(await phone.capture.turnOn(), TurnOnResult.blocked);
      expect(phone.capture.isOn, isFalse);
      expect(phone.bridge.listening, isFalse);
    });

    test('turning off stops the receiver', () async {
      await phone.capture.turnOn();
      await phone.capture.turnOff();
      expect(phone.bridge.listening, isFalse);
      expect(phone.capture.isOn, isFalse);
    });

    test('permission taken away later is noticed', () async {
      await phone.capture.turnOn();
      phone.bridge.current = SmsAccess.denied;
      await phone.capture.refresh();
      expect(phone.capture.needsPermission, isTrue);
    });
  });

  group('collecting', () {
    setUp(() => phone.capture.turnOn());

    test('later scans start from the previous one, less a day of overlap', () async {
      final firstScan = Phone.now;
      Phone.now = Phone.now.add(const Duration(hours: 5));
      await phone.capture.refresh();
      expect(phone.bridge.inboxReadsSince.last, firstScan.subtract(const Duration(days: 1)));
    });

    test('"scan again" goes back the full 30 days', () async {
      Phone.now = Phone.now.add(const Duration(hours: 5));
      await phone.capture.refresh(rescan: true);
      expect(phone.bridge.inboxReadsSince.last, Phone.now.subtract(const Duration(days: 30)));
    });

    test('an SMS arriving while the app is open shows up', () async {
      phone.bridge.arrive(sms(airtelReceived));
      await until(() => phone.capture.pendingCount == 1);
    });

    test('the same SMS from the queue and the inbox is captured once', () async {
      phone.bridge.queue.add(sms(airtelSent, at: DateTime(2026, 10, 12, 8, 59)));
      phone.bridge.inbox.add(sms(airtelSent.replaceAll('. ', '.\n'), at: DateTime(2026, 10, 12, 8, 58)));
      expect(await phone.capture.refresh(), 1);
      expect(phone.capture.pendingCount, 1);
    });

    test('a message with no transaction ID, seen twice with different line breaks, is captured once', () async {
      phone.bridge.queue.add(sms(nssfInterest, sender: 'NSSF', at: DateTime(2026, 10, 12, 8, 50)));
      phone.bridge.inbox.add(
          sms(nssfInterest.replaceAll(', ', ',\n'), sender: 'NSSF', at: DateTime(2026, 10, 12, 8, 52)));
      await phone.capture.refresh();
      expect(phone.capture.pendingCount, 1);
    });

    test('the same transaction in two wordings is captured once', () async {
      await phone.capture.ingest([sms(airtelSent), sms('$airtelSent Thank you for using Airtel Money.')]);
      expect(phone.capture.pendingCount, 1);
    });

    test('pasted messages are added once, and only money messages', () async {
      expect(await phone.capture.addPasted(airtelPaid), isTrue);
      expect(await phone.capture.addPasted(airtelPaid), isFalse);
      expect(await phone.capture.addPasted('See you at 6pm'), isFalse);
      expect(phone.capture.pending.single.record.sender, '');
    });

    test('waiting messages survive a restart', () async {
      await phone.capture.ingest([sms(airtelSent), sms(airtelReceived)]);
      phone = await phone.restart();
      expect(phone.capture.pendingCount, 2);
    });

    test('handled messages are deleted after 60 days; waiting ones are kept', () async {
      final old = DateTime(2026, 8, 1);
      await phone.capture.ingest([sms(airtelSent, at: old), sms(airtelReceived, at: old)]);
      await phone.capture.ignore(phone.capture.pending.firstWhere((c) => c.message.amount == 21000));
      Phone.now = DateTime(2026, 10, 12);
      phone = await phone.restart();
      expect(phone.capture.pending.map((c) => c.message.amount), [51000]);
      expect(phone.capture.recentlyHandled, isEmpty);
    });

    test('a message confirmed on another phone (restored from backup) is not offered again', () async {
      await phone.vm.addTransaction(TxRecord(
        id: 'sms_${CaptureService.fingerprint(airtelReceived)}',
        type: TxType.income,
        amount: 51000,
        walletId: 'wallet_airtel',
        dateTime: DateTime(2026, 10, 5, 8),
      ));
      expect(await phone.capture.ingest([sms(airtelReceived)]), 0);
      expect(phone.capture.pendingCount, 0);
    });
  });

  group('confirming', () {
    test('a send is an expense, with the fee as its own expense', () async {
      await phone.capture.ingest([sms(airtelSent)]);
      final c = phone.capture.pending.single;
      final draft = phone.capture.draftFor(c);
      expect(draft.isComplete, isFalse, reason: 'no category for a person yet');
      expect(() => phone.capture.confirm(c), throwsStateError);

      await phone.capture.confirm(c, draft..categoryId = 'cat_expense_food');

      final main = phone.tx('sms_${c.id}')!;
      expect(main.type, TxType.expense);
      expect(main.amount, 21000);
      expect(main.walletId, 'wallet_airtel');
      expect(main.categoryId, 'cat_expense_food');
      expect(main.note, 'Grace Akello');
      expect(main.dateTime, DateTime(2026, 10, 5, 8, 0));
      final fee = phone.tx('sms_${c.id}_fee')!;
      expect(fee.amount, 500);
      expect(fee.walletId, 'wallet_airtel');
      expect(fee.categoryId, CaptureSuggestions.feesCategoryId);
      expect(phone.vm.categoryById(CaptureSuggestions.feesCategoryId)?.name, 'Fees & Charges');
      expect(phone.capture.pendingCount, 0);
      expect(c.record.status, CaptureStatus.confirmed);
    });

    test('the category chosen for someone is suggested next time', () async {
      await phone.capture.ingest([sms(airtelSent)]);
      final first = phone.capture.pending.single;
      await phone.capture.confirm(first, phone.capture.draftFor(first)..categoryId = 'cat_expense_rent');

      await phone.capture.ingest([sms(airtelSent2)]);
      final next = phone.capture.draftFor(phone.capture.pending.single);
      expect(next.categoryId, 'cat_expense_rent');
      expect(next.isComplete, isTrue);
    });

    test('the wallet chosen for a provider is used next time', () async {
      await phone.capture.ingest([sms(airtelSent)]);
      final first = phone.capture.pending.single;
      await phone.capture.confirm(
          first, phone.capture.draftFor(first)..walletId = 'wallet_cash'..categoryId = 'cat_expense_food');

      await phone.capture.ingest([sms(airtelSent2)]);
      expect(phone.capture.draftFor(phone.capture.pending.single).walletId, 'wallet_cash');
    });

    test('a bank deposit is saved as a transfer Bank → Airtel; no fee record without a fee', () async {
      await phone.capture.ingest([sms(airtelDeposit)]);
      final c = phone.capture.pending.single;
      await phone.capture.confirm(c);
      final t = phone.tx('sms_${c.id}')!;
      expect(t.type, TxType.transfer);
      expect(t.walletId, 'wallet_bank');
      expect(t.toWalletId, 'wallet_airtel');
      expect(t.categoryId, '');
      expect(phone.tx('sms_${c.id}_fee'), isNull);
    });

    test('undo removes what confirming created and puts it back for review', () async {
      await phone.capture.ingest([sms(airtelSent)]);
      final c = phone.capture.pending.single;
      await phone.capture.confirm(c, phone.capture.draftFor(c)..categoryId = 'cat_expense_food');
      expect(phone.capture.recentlyHandled.single.id, c.id);

      await phone.capture.undo(c);

      expect(phone.tx('sms_${c.id}'), isNull);
      expect(phone.tx('sms_${c.id}_fee'), isNull);
      expect(phone.capture.pendingCount, 1);
      expect(phone.capture.recentlyHandled, isEmpty);
    });

    test('ignore, then undo', () async {
      await phone.capture.ingest([sms(airtelSent)]);
      final c = phone.capture.pending.single;
      await phone.capture.ignore(c);
      expect(phone.capture.pendingCount, 0);
      expect(phone.vm.transactions, isEmpty);
      await phone.capture.undo(c);
      expect(phone.capture.pendingCount, 1);
    });

    test('a transaction typed in by hand is flagged as a possible duplicate', () async {
      await phone.vm.addTransaction(TxRecord(
        id: 'manual1',
        type: TxType.income,
        amount: 51000,
        walletId: 'wallet_airtel',
        categoryId: 'cat_income_other',
        dateTime: DateTime(2026, 10, 5, 19, 0),
      ));
      await phone.capture.ingest([sms(airtelReceived), sms(umeme)]);
      final received = phone.capture.pending.firstWhere((c) => c.message.amount == 51000);
      final paid = phone.capture.pending.firstWhere((c) => c.message.amount == 5000);
      expect(phone.capture.possibleDuplicate(received)?.id, 'manual1');
      expect(phone.capture.possibleDuplicate(paid), isNull);

      final other = phone.capture.draftFor(received)..amount = 50000;
      expect(phone.capture.possibleDuplicate(received, other), isNull, reason: 'different amount');
    });

    test('confirm all saves complete suggestions and leaves the rest', () async {
      await phone.vm.addTransaction(TxRecord(
        id: 'manual1',
        type: TxType.income,
        amount: 51000,
        walletId: 'wallet_airtel',
        categoryId: 'cat_income_other',
        dateTime: DateTime(2026, 10, 5, 19, 0),
      ));
      await phone.capture.ingest([
        sms(umeme), // Electricity: complete
        sms(airtelDeposit), // transfer: complete
        sms(airtelSent), // a person: no category
        sms(airtelReceived), // looks like manual1
      ]);

      final result = await phone.capture.confirmAll();

      expect(result.confirmed, 2);
      expect(result.skipped, 2);
      expect(phone.capture.pending.map((c) => c.message.amount).toSet(), {21000, 51000});
    });
  });

  group('balance check', () {
    test('offers to match the wallet to the newest SMS balance', () async {
      await phone.capture.ingest([sms(airtelSent)]);
      final c = phone.capture.pending.single;
      final mismatch = await phone.capture.confirm(c, phone.capture.draftFor(c)..categoryId = 'cat_expense_food');

      expect(mismatch, isNotNull);
      expect(mismatch!.walletId, 'wallet_airtel');
      expect(mismatch.smsBalance, 11450);
      expect(mismatch.appBalance, -21500);

      await phone.capture.matchBalance(mismatch);
      expect(phone.vm.walletBalance('wallet_airtel'), 11450);
      expect(phone.tx('sms_${c.id}'), isNotNull, reason: 'the transaction itself is kept');
    });

    test('says nothing when an older message is confirmed before a newer one', () async {
      await phone.capture.ingest([sms(airtelDeposit), sms(airtelPaid)]); // 06:15, then 06:38
      final older = phone.capture.pending.firstWhere((c) => c.message.amount == 31200);
      expect(await phone.capture.confirm(older), isNull);
    });

    test('says nothing when the balance already matches', () async {
      final airtel = phone.vm.walletById('wallet_airtel');
      await phone.vm.setWalletBalance(airtel, 33675 - 31200);
      await phone.capture.ingest([sms(airtelDeposit)]);
      expect(await phone.capture.confirm(phone.capture.pending.single), isNull);
    });

    test('confirm all reports one mismatch per wallet, for the newest message', () async {
      await phone.vm.saveWallet(Wallet(id: 'w_save', name: 'NSSF', type: WalletType.savings));
      await phone.capture.ingest(
          [sms(airtelDeposit), sms(umeme, at: DateTime(2026, 10, 6)), sms(nssfInterest, sender: 'NSSF')]);
      final result = await phone.capture.confirmAll();
      expect(result.confirmed, 3);
      expect({for (final m in result.mismatches) m.walletId: m.smsBalance}, {'wallet_airtel': 2675, 'w_save': 10331});
    });
  });
}
