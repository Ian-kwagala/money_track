import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted, deliberately slow hashes of the app-lock PIN (PBKDF2-HMAC-SHA256),
/// so the PIN itself is never stored.
///
/// Stored as `pbkdf2-sha256$<iterations>$<salt>$<hash>` (salt and hash in
/// base64). The iteration count travels with each hash, so it can be raised
/// later without breaking PINs set earlier.
class PinHash {
  static const _scheme = 'pbkdf2-sha256';

  /// About 0.1 s on a desktop and a few tenths of a second on a phone: slow
  /// enough to make guessing from a copied data file costly, fast enough
  /// for unlocking.
  static const defaultIterations = 20000;

  /// A new hash of [pin] with a fresh random salt. Runs off the UI thread.
  static Future<String> create(String pin, {int iterations = defaultIterations}) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final hash = await Isolate.run(() => _pbkdf2(utf8.encode(pin), salt, iterations));
    return '$_scheme\$$iterations\$${base64Encode(salt)}\$${base64Encode(hash)}';
  }

  /// Whether [stored] is a hash made by [create] (rather than an old,
  /// plain-text PIN).
  static bool isHash(String? stored) => stored != null && stored.startsWith('$_scheme\$');

  /// Whether [pin] is the PIN [stored] was made from. False for anything
  /// that isn't a well-formed hash.
  static Future<bool> verify(String pin, String stored) async {
    // Unpack "scheme$iterations$salt$hash", then re-hash the PIN with the
    // same salt and iteration count and compare.
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = await Isolate.run(() => _pbkdf2(utf8.encode(pin), salt, iterations));
    return _sameBytes(actual, expected);
  }

  /// PBKDF2 with HMAC-SHA256 (RFC 8018), one 32-byte block.
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    // U1 = HMAC(password, salt || INT(1)), where INT(1) is the block index
    // as a 4-byte big-endian number. One block is enough for a 32-byte key.
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    // U2..Un: each round hashes the previous one, and the result is the XOR
    // of every round.
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  /// Compares in constant time, so timing doesn't reveal how much matched.
  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
