import 'package:flutter_test/flutter_test.dart';
import 'package:studchat/core/mesh/envelope.dart';

void main() {
  group('Envelope', () {
    test('round-trips through the wire form', () {
      const Envelope original = Envelope(
        id: 'abc-123',
        kind: EnvelopeKind.msg,
        fromId: 'alice',
        toId: 'bob',
        body: 'hello, world',
        ts: 1720000000000,
        ttl: 8,
      );

      final Envelope decoded = Envelope.decode(original.encode());

      expect(decoded.id, original.id);
      expect(decoded.kind, EnvelopeKind.msg);
      expect(decoded.fromId, 'alice');
      expect(decoded.toId, 'bob');
      expect(decoded.body, 'hello, world');
      expect(decoded.ts, original.ts);
      expect(decoded.ttl, 8);
    });

    test('carries a display name only on hello', () {
      const Envelope hello = Envelope(
        id: 'h1',
        kind: EnvelopeKind.hello,
        fromId: 'alice',
        toId: '',
        body: '',
        ts: 1,
        ttl: 0,
        name: 'Alice',
      );
      final Map<String, Object?> json = hello.toJson();
      expect(json['n'], 'Alice');

      const Envelope msg = Envelope(
        id: 'm1',
        kind: EnvelopeKind.msg,
        fromId: 'a',
        toId: 'b',
        body: 'x',
        ts: 1,
        ttl: 4,
      );
      // No name key emitted when empty - keeps the wire compact.
      expect(msg.toJson().containsKey('n'), isFalse);
    });

    test('relayed() decrements ttl but preserves the dedup id', () {
      const Envelope e = Envelope(
        id: 'keep-me',
        kind: EnvelopeKind.msg,
        fromId: 'a',
        toId: 'b',
        body: 'x',
        ts: 1,
        ttl: 3,
      );
      final Envelope hopped = e.relayed();
      expect(hopped.ttl, 2);
      expect(hopped.id, 'keep-me');
      expect(hopped, equals(e)); // equality is by id
    });

    test('round-trips encryption flag + signature, and relaying keeps them',
        () {
      const Envelope enc = Envelope(
        id: 'e1',
        kind: EnvelopeKind.msg,
        fromId: 'a',
        toId: 'b',
        body: 'BASE64CIPHERTEXT',
        ts: 5,
        ttl: 8,
        enc: true,
        sig: 'BASE64SIG',
      );
      final Envelope decoded = Envelope.decode(enc.encode());
      expect(decoded.enc, isTrue);
      expect(decoded.sig, 'BASE64SIG');
      expect(decoded.body, 'BASE64CIPHERTEXT');
      // A relay must carry the ciphertext + signature through unchanged.
      final Envelope hopped = decoded.relayed();
      expect(hopped.enc, isTrue);
      expect(hopped.sig, 'BASE64SIG');

      // A plaintext envelope omits the encryption keys for a compact wire form.
      const Envelope plain = Envelope(
        id: 'p1',
        kind: EnvelopeKind.msg,
        fromId: 'a',
        toId: 'b',
        body: 'hi',
        ts: 1,
        ttl: 4,
      );
      expect(plain.toJson().containsKey('e2'), isFalse);
      expect(plain.toJson().containsKey('sg'), isFalse);
      expect(Envelope.decode(plain.encode()).enc, isFalse);
    });

    test('rejects malformed payloads with FormatException', () {
      expect(() => Envelope.decode('not json'), throwsFormatException);
      expect(() => Envelope.decode('[]'), throwsFormatException);
      expect(
        () => Envelope.decode('{"id":"x"}'), // missing required fields
        throwsFormatException,
      );
      expect(
        () => Envelope.decode('{"id":"x","k":"bogus","f":"a","ts":1,"ttl":1}'),
        throwsFormatException,
      );
    });

    test('tolerates a missing optional toId/body', () {
      final Envelope e = Envelope.decode(
        '{"id":"x","k":"hello","f":"a","ts":1,"ttl":0}',
      );
      expect(e.toId, '');
      expect(e.body, '');
      expect(e.isHello, isTrue);
    });
  });
}
