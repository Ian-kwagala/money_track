import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:money_track/data/money_repository.dart';
import 'package:money_track/services/security/pin_hash.dart';
import 'package:money_track/viewmodels/tracker_view_model.dart';

// Tests for the app lock in TrackerViewModel: setting, checking and turning
// off the PIN, and upgrading PINs that older versions stored in plain text.
// They run on real Hive files, so they can also check that the PIN never
// appears in the settings file on disk.

/// A PIN unlikely to appear in the settings file by chance.
const _pin = '918273';

void main() {
  late Directory dir;
  late MoneyRepository repo;
  late TrackerViewModel vm;

  // A fresh temporary storage folder for every test.
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mt_lock_test');
    repo = MoneyRepository();
    await repo.init(hivePath: dir.path);
    vm = TrackerViewModel(repo);
  });
  tearDown(() => Hive.close());

  /// Whether the PIN can be found anywhere in the settings file on disk.
  bool pinOnDisk() {
    final bytes = File('${dir.path}/settings.hive').readAsBytesSync();
    return String.fromCharCodes(bytes).contains(_pin);
  }

  test('setting a PIN stores only a hash, and locks the app', () async {
    await vm.setPin(_pin);
    expect(PinHash.isHash(vm.settings.appLockPasswordHash), isTrue);
    expect(vm.settings.appLockPin, isNull);
    expect(vm.hasPin, isTrue);
    expect(vm.isAppLocked, isTrue);
    expect(vm.isUnlocked, isFalse);
    expect(pinOnDisk(), isFalse);
  });

  test('only the right PIN unlocks', () async {
    await vm.setPin(_pin);
    expect(await vm.verifyPin(_pin), isTrue);
    expect(await vm.verifyPin('918274'), isFalse);
    expect(await vm.verifyPin(''), isFalse);
  });

  test('turning the lock off and on again keeps the same PIN working', () async {
    await vm.setPin(_pin);
    await vm.setAppLockEnabled(false);
    expect(vm.isAppLocked, isFalse);
    expect(vm.isUnlocked, isTrue);
    expect(vm.hasPin, isTrue);

    await vm.setAppLockEnabled(true);
    expect(vm.isAppLocked, isTrue);
    expect(await vm.verifyPin(_pin), isTrue);
  });

  test('the lock can\'t be turned on without a PIN', () async {
    await vm.setAppLockEnabled(true);
    expect(vm.isAppLocked, isFalse);
    expect(vm.settings.appLockEnabled, isFalse);
  });

  test('a plain-text PIN from an older version is hashed and wiped from disk', () async {
    final s = vm.settings
      ..appLockEnabled = true
      ..appLockPin = _pin
      ..appLockPasswordHash = _pin; // older versions stored it here too
    await repo.updateSettings(s);
    expect(pinOnDisk(), isTrue, reason: 'sanity check: the old version left it readable');

    await vm.hashLegacyPin();

    expect(vm.settings.appLockPin, isNull);
    expect(PinHash.isHash(vm.settings.appLockPasswordHash), isTrue);
    expect(pinOnDisk(), isFalse);
    expect(vm.isAppLocked, isTrue);
    expect(await vm.verifyPin(_pin), isTrue);
    expect(await vm.verifyPin('0000'), isFalse);
  });

  test('the upgrade also survives a restart', () async {
    await repo.updateSettings(vm.settings
      ..appLockEnabled = true
      ..appLockPin = _pin);
    await vm.hashLegacyPin();
    await Hive.close();

    // Reopen the same storage, as the next app launch would.
    repo = MoneyRepository();
    await repo.init(hivePath: dir.path);
    vm = TrackerViewModel(repo);
    expect(vm.isAppLocked, isTrue);
    expect(await vm.verifyPin(_pin), isTrue);
    expect(pinOnDisk(), isFalse);
  });

  test('an old plain-text PIN still unlocks if the upgrade hasn\'t run, and is hashed then', () async {
    await repo.updateSettings(vm.settings
      ..appLockEnabled = true
      ..appLockPin = _pin);

    expect(await vm.verifyPin('0000'), isFalse);
    expect(vm.settings.appLockPin, _pin, reason: 'a wrong guess changes nothing');
    expect(await vm.verifyPin(_pin), isTrue);
    expect(vm.settings.appLockPin, isNull);
    expect(PinHash.isHash(vm.settings.appLockPasswordHash), isTrue);
  });

  test('onboarding with a PIN stores only a hash and leaves the app unlocked', () async {
    await vm.completeOnboarding(
      name: 'Grace',
      phone: '0700000000',
      email: 'g@example.com',
      incomeSource: 'salary',
      pin: _pin,
      enableLock: true,
    );
    expect(vm.isAppLocked, isTrue);
    expect(vm.isUnlocked, isTrue);
    expect(vm.settings.appLockPin, isNull);
    expect(await vm.verifyPin(_pin), isTrue);
    expect(pinOnDisk(), isFalse);
  });
}
