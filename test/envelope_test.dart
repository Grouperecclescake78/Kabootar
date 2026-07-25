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
      final Envelope e =
          Envelope.decode('{"id":"x","k":"hello","f":"a","ts":1,"ttl":0}');
      expect(e.toId, '');
      expect(e.body, '');
      expect(e.isHello, isTrue);
    });
  });
}
