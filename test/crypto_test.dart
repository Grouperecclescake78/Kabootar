import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studchat/core/crypto/app_keys.dart';

void main() {
  group('AppKeys', () {
    test('encrypt -> decrypt round-trips between two devices', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final PeerKeys bobPub = AppKeys.parseBundle(bob.publicBundle)!;
      final PeerKeys alicePub = AppKeys.parseBundle(alice.publicBundle)!;

      final String blob =
          await alice.seal(bobPub.agree, utf8.encode('meet at 5'));
      final List<int>? out = await bob.open(alicePub.agree, blob);

      expect(out, isNotNull);
      expect(utf8.decode(out!), 'meet at 5');
    });

    test('a tampered ciphertext fails to decrypt (returns null)', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final PeerKeys bobPub = AppKeys.parseBundle(bob.publicBundle)!;
      final PeerKeys alicePub = AppKeys.parseBundle(alice.publicBundle)!;

      final String blob = await alice.seal(bobPub.agree, utf8.encode('secret'));
      // Flip a character in the middle of the blob.
      final int i = blob.length ~/ 2;
      final String bad = blob.substring(0, i) +
          (blob[i] == 'A' ? 'B' : 'A') +
          blob.substring(i + 1);

      expect(await bob.open(alicePub.agree, bad), isNull);
    });

    test('a third party cannot decrypt', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final AppKeys eve = await AppKeys.generate();
      final PeerKeys bobPub = AppKeys.parseBundle(bob.publicBundle)!;
      final PeerKeys alicePub = AppKeys.parseBundle(alice.publicBundle)!;

      final String blob = await alice.seal(bobPub.agree, utf8.encode('hi bob'));
      // Eve intercepts but only has Alice's public key, not Bob's private key.
      expect(await eve.open(alicePub.agree, blob), isNull);
    });

    test('signatures verify and reject tampering', () async {
      final AppKeys alice = await AppKeys.generate();
      final PeerKeys alicePub = AppKeys.parseBundle(alice.publicBundle)!;
      final List<int> msg = utf8.encode('id|A|B|hello');

      final String sig = await alice.signB64(msg);
      expect(await AppKeys.verifyB64(msg, sig, alicePub.sign), isTrue);
      expect(
        await AppKeys.verifyB64(
            utf8.encode('id|A|B|HELLO'), sig, alicePub.sign),
        isFalse,
      );
    });

    test('seeds export and re-import to the same identity', () async {
      final AppKeys a = await AppKeys.generate();
      final String seeds = await a.exportSeeds();
      final AppKeys restored = await AppKeys.fromSeeds(seeds);
      expect(restored.publicBundle, a.publicBundle);

      // A message sealed to the restored identity still opens.
      final AppKeys bob = await AppKeys.generate();
      final PeerKeys restoredPub = AppKeys.parseBundle(restored.publicBundle)!;
      final PeerKeys bobPub = AppKeys.parseBundle(bob.publicBundle)!;
      final String blob = await bob.seal(restoredPub.agree, utf8.encode('x'));
      expect(await restored.open(bobPub.agree, blob), isNotNull);
    });

    test('group key seals and opens for members, not outsiders', () async {
      final String key = await AppKeys.newGroupKey();
      final String blob =
          await AppKeys.sealSym(key, utf8.encode('group secret'));

      final List<int>? member = await AppKeys.openSym(key, blob);
      expect(member, isNotNull);
      expect(utf8.decode(member!), 'group secret');

      // A different group key cannot open it.
      final String otherKey = await AppKeys.newGroupKey();
      expect(await AppKeys.openSym(otherKey, blob), isNull);
    });

    test('safety code is stable and formatted', () async {
      final AppKeys a = await AppKeys.generate();
      final String code = await a.safetyCode();
      expect(
          code,
          matches(
              RegExp(r'^[0-9A-F]{4} [0-9A-F]{4} [0-9A-F]{4} [0-9A-F]{4}$')));
      expect(await a.safetyCode(), code); // stable
    });
  });
}
