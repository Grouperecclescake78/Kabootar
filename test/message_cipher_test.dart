import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabootar/core/crypto/app_keys.dart';
import 'package:kabootar/core/crypto/message_cipher.dart';
import 'package:kabootar/core/mesh/envelope.dart';

/// Build a cipher for [me] that knows [peers]' public keys and the given group
/// keys. `isGroup` is derived from the group-key map.
MessageCipher _cipherFor(
  AppKeys me,
  String myId, {
  Map<String, AppKeys> peers = const <String, AppKeys>{},
  Map<String, String> groupKeys = const <String, String>{},
}) {
  final Map<String, PeerKeys> pub = <String, PeerKeys>{
    for (final MapEntry<String, AppKeys> e in peers.entries)
      e.key: AppKeys.parseBundle(e.value.publicBundle)!,
  };
  return MessageCipher(
    keys: me,
    myId: myId,
    ttl: 8,
    peerKeyOf: (String id) => pub[id],
    groupKeyOf: (String id) => groupKeys[id],
    isGroup: groupKeys.containsKey,
  );
}

void main() {
  group('MessageCipher - 1:1', () {
    test('encrypts + signs to a known peer, and the peer opens it', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final MessageCipher aliceC =
          _cipherFor(alice, 'A', peers: <String, AppKeys>{'B': bob});
      final MessageCipher bobC =
          _cipherFor(bob, 'B', peers: <String, AppKeys>{'A': alice});

      final Envelope env = await aliceC.buildOutgoing(
          id: 'm1', toId: 'B', plaintext: 'meet at 5', ts: 1000);
      expect(env.enc, isTrue);
      expect(env.sig, isNotEmpty);
      expect(env.body, isNot('meet at 5')); // ciphertext on the wire

      expect(await bobC.openDirectMessage(env), 'meet at 5');
    });

    test('falls back to plaintext when the peer key is unknown', () async {
      final AppKeys alice = await AppKeys.generate();
      final MessageCipher aliceC = _cipherFor(alice, 'A');
      final Envelope env = await aliceC.buildOutgoing(
          id: 'm1', toId: 'B', plaintext: 'hi', ts: 1);
      expect(env.enc, isFalse);
      expect(env.body, 'hi');
    });

    test('a tampered ciphertext is rejected (returns null)', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final MessageCipher aliceC =
          _cipherFor(alice, 'A', peers: <String, AppKeys>{'B': bob});
      final MessageCipher bobC =
          _cipherFor(bob, 'B', peers: <String, AppKeys>{'A': alice});
      final Envelope env = await aliceC.buildOutgoing(
          id: 'm1', toId: 'B', plaintext: 'secret', ts: 1);

      final Envelope tampered = Envelope(
        id: env.id,
        kind: env.kind,
        fromId: env.fromId,
        toId: env.toId,
        body: '${env.body}x', // corrupt the ciphertext
        ts: env.ts,
        ttl: env.ttl,
        enc: true,
        sig: env.sig,
      );
      expect(await bobC.openDirectMessage(tampered), isNull);
    });

    test('a placeholder is shown when the sender key is unknown', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final MessageCipher aliceC =
          _cipherFor(alice, 'A', peers: <String, AppKeys>{'B': bob});
      // Bob does not know Alice's key.
      final MessageCipher bobC = _cipherFor(bob, 'B');
      final Envelope env = await aliceC.buildOutgoing(
          id: 'm1', toId: 'B', plaintext: 'hey', ts: 1);
      expect(await bobC.openDirectMessage(env), '🔒 Encrypted message');
    });
  });

  group('MessageCipher - group', () {
    test('seals with the group key; a member opens it', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final String gk = await AppKeys.newGroupKey();
      final MessageCipher aliceC = _cipherFor(alice, 'A',
          peers: <String, AppKeys>{'B': bob},
          groupKeys: <String, String>{'g1': gk});
      final MessageCipher bobC = _cipherFor(bob, 'B',
          peers: <String, AppKeys>{'A': alice},
          groupKeys: <String, String>{'g1': gk});

      final (String blob, bool enc) =
          await aliceC.encryptFor('g1', utf8.encode('group hi'));
      expect(enc, isTrue);

      final Envelope msg = Envelope(
        id: 'gm1',
        kind: EnvelopeKind.msg,
        fromId: 'A',
        toId: 'g1',
        body: blob,
        ts: 1,
        ttl: 8,
        enc: true,
        sig: await alice.signB64(MessageCipher.signedBytes(
            id: 'gm1', from: 'A', to: 'g1', ts: 1, body: blob)),
      );
      expect(await bobC.openGroupMessage(msg, gk), 'group hi');
    });
  });

  group('MessageCipher - media payloads', () {
    test('round-trips an encrypted media payload', () async {
      final AppKeys alice = await AppKeys.generate();
      final AppKeys bob = await AppKeys.generate();
      final MessageCipher aliceC =
          _cipherFor(alice, 'A', peers: <String, AppKeys>{'B': bob});
      final MessageCipher bobC =
          _cipherFor(bob, 'B', peers: <String, AppKeys>{'A': alice});

      final (String blob, bool enc) =
          await aliceC.encryptFor('B', <int>[1, 2, 3, 4, 5]);
      expect(enc, isTrue);
      final List<int>? out = await bobC.decryptPayload(
          enc: true, convId: 'B', fromId: 'A', b64: blob);
      expect(out, <int>[1, 2, 3, 4, 5]);
    });
  });
}
