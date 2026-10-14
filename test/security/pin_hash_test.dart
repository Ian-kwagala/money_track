import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/services/security/pin_hash.dart';

// Tests for PinHash, which stores the app-lock PIN as
// "pbkdf2-sha256$<iterations>$<base64 salt>$<base64 hash>" instead of the PIN
// itself. The first test checks the PBKDF2 maths against known answers; the
// rest check the stored format and that only the right PIN verifies.

/// Turns a hex string into bytes.
List<int> _hex(String s) => [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];

/// A stored hash built by hand from a published PBKDF2-HMAC-SHA256 test
/// vector (password "password", salt "salt").
String _vector(int iterations, String expectedHex) =>
    'pbkdf2-sha256\$$iterations\$${base64Encode(utf8.encode('salt'))}\$${base64Encode(_hex(expectedHex))}';

void main() {
  test('matches the published PBKDF2-HMAC-SHA256 test vectors', () async {
    expect(
        await PinHash.verify('password',
            _vector(1, '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b')),
        isTrue);
    expect(
        await PinHash.verify('password',
            _vector(2, 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43')),
        isTrue);
    expect(
        await PinHash.verify('password',
            _vector(4096, 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a')),
        isTrue);
  });

  test('the right PIN verifies, a wrong one does not', () async {
    final stored = await PinHash.create('918273');
    expect(PinHash.isHash(stored), isTrue);
    expect(await PinHash.verify('918273', stored), isTrue);
    expect(await PinHash.verify('918274', stored), isFalse);
    expect(await PinHash.verify('', stored), isFalse);
  });

  test('the PIN itself is not in what gets stored', () async {
    final stored = await PinHash.create('918273');
    expect(stored, isNot(contains('918273')));
    expect(stored, startsWith('pbkdf2-sha256\$${PinHash.defaultIterations}\$'));
  });

  test('each hash gets its own salt', () async {
    expect(await PinHash.create('1234'), isNot(await PinHash.create('1234')));
  });

  test('the iteration count travels with the hash', () async {
    final stored = await PinHash.create('1234', iterations: 1000);
    expect(stored.split('\$')[1], '1000');
    expect(await PinHash.verify('1234', stored), isTrue);
  });

  test('anything that is not a well-formed hash never verifies', () async {
    for (final stored in [
      '1234', // an old plain-text PIN
      '',
      'pbkdf2-sha256\$x\$c2FsdA==\$AAAA',
      'pbkdf2-sha256\$0\$c2FsdA==\$AAAA',
      'pbkdf2-sha256\$10\$not base64!\$AAAA',
      'pbkdf2-sha256\$10\$c2FsdA==',
    ]) {
      expect(await PinHash.verify('1234', stored), isFalse, reason: stored);
    }
    expect(PinHash.isHash('1234'), isFalse);
    expect(PinHash.isHash(null), isFalse);
  });
}
