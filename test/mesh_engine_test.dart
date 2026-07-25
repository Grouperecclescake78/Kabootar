import 'package:flutter_test/flutter_test.dart';
import 'package:studchat/core/mesh/envelope.dart';
import 'package:studchat/core/mesh/mesh_config.dart';
import 'package:studchat/core/mesh/mesh_ports.dart';

import 'support/in_memory_mesh.dart';

void main() {
  group('MeshEngine - delivery', () {
    test(
      'delivers a message and returns an end-to-end ack (A <-> B)',
      () async {
        final MeshNetwork net = MeshNetwork();
        net.add('A');
        net.add('B');
        net.connect('A', 'B');

        final Envelope sent = await net.nodes['A']!.engine.sendMessage(
          toId: 'B',
          body: 'hey',
        );
        await net.pump();

        expect(net.nodes['B']!.delegate.delivered.single.body, 'hey');
        expect(net.nodes['A']!.delegate.acked, contains(sent.id));
      },
    );

    test('never delivers the same envelope twice (de-dup)', () async {
      final MeshNetwork net = MeshNetwork();
      final Node b = net.add('B');
      net.add('A');
      net.connect('A', 'B');

      const Envelope e = Envelope(
        id: 'dupe',
        kind: EnvelopeKind.msg,
        fromId: 'A',
        toId: 'B',
        body: 'once',
        ts: 1000,
        ttl: 4,
      );
      await b.engine.onEnvelopeReceived(e, fromPeerId: 'A');
      await b.engine.onEnvelopeReceived(e, fromPeerId: 'A');
      await net.pump();

      expect(b.delegate.delivered.length, 1);
      expect(b.delegate.count(MeshEventType.duplicateDropped), 1);
    });
  });

  group('MeshEngine - relay & carry', () {
    test('relays through an uninvolved node (A - R - C)', () async {
      final MeshNetwork net = MeshNetwork();
      net.add('A');
      final Node r = net.add('R');
      net.add('C');
      net.connect('A', 'R');
      net.connect('R', 'C');

      final Envelope sent = await net.nodes['A']!.engine.sendMessage(
        toId: 'C',
        body: 'via relay',
      );
      await net.pump();

      expect(net.nodes['C']!.delegate.delivered.single.body, 'via relay');
      expect(r.delegate.delivered, isEmpty); // R is only a courier
      expect(r.delegate.count(MeshEventType.relayed), greaterThan(0));
      expect(net.nodes['A']!.delegate.acked, contains(sent.id));
    });

    test(
      'store-and-forward: offline recipient receives after returning',
      () async {
        final MeshNetwork net = MeshNetwork();
        net.add('A');
        final Node r = net.add('R');
        net.add('C');

        net.connect('A', 'R');
        final Envelope sent = await net.nodes['A']!.engine.sendMessage(
          toId: 'C',
          body: 'catch me later',
        );
        await net.pump();

        expect(net.nodes['C']!.delegate.delivered, isEmpty);
        expect(r.engine.carriedCount, greaterThanOrEqualTo(1));

        net.disconnect('A', 'R');
        net.advanceClock(60000);
        net.connect('R', 'C'); // flush-on-connect carries the last hop
        await net.pump();

        expect(
          net.nodes['C']!.delegate.delivered.single.body,
          'catch me later',
        );

        net.disconnect('R', 'C');
        net.connect('A', 'R'); // ack finds its way home
        await net.pump();
        expect(net.nodes['A']!.delegate.acked, contains(sent.id));
      },
    );

    test('seeing an ack stops a relay from carrying the message', () async {
      final MeshNetwork net = MeshNetwork();
      net.add('A');
      final Node r = net.add('R');
      net.add('C');
      net.connect('A', 'R');
      net.connect('R', 'C');

      await net.nodes['A']!.engine.sendMessage(toId: 'C', body: 'clean up');
      await net.pump();

      expect(
        r.delegate.count(MeshEventType.carryCleared),
        greaterThanOrEqualTo(1),
      );
    });
  });

  group('MeshEngine - bounds', () {
    test('drops a message that arrives with no hops left', () async {
      final MeshNetwork net = MeshNetwork();
      net.add('A');
      final Node r = net.add('R');
      net.add('C');
      net.connect('A', 'R');
      net.connect('R', 'C');

      const Envelope e = Envelope(
        id: 'ttl0',
        kind: EnvelopeKind.msg,
        fromId: 'A',
        toId: 'C',
        body: 'short legs',
        ts: 1000,
        ttl: 0,
      );
      await r.engine.onEnvelopeReceived(e, fromPeerId: 'A');
      await net.pump();

      expect(r.delegate.count(MeshEventType.ttlExpired), 1);
      expect(net.nodes['C']!.delegate.delivered, isEmpty);
    });

    test('carry-cache evicts the oldest past capacity', () async {
      final MeshNetwork net = MeshNetwork();
      final Node r = net.add(
        'R',
        config: const MeshConfig(ttl: 8, maxCacheSize: 3),
      );
      for (int i = 0; i < 5; i++) {
        await r.engine.onEnvelopeReceived(
          Envelope(
            id: 'm$i',
            kind: EnvelopeKind.msg,
            fromId: 'A',
            toId: 'Z',
            body: 'x',
            ts: 1000 + i,
            ttl: 4,
          ),
          fromPeerId: 'A',
        );
      }
      expect(r.engine.carriedCount, 3);
      expect(r.delegate.count(MeshEventType.cacheEvicted), 2);
    });

    test(
      'housekeeping ages out stale carried envelopes and seen records',
      () async {
        final MeshNetwork net = MeshNetwork();
        final Node r = net.add(
          'R',
          config: const MeshConfig(
            ttl: 8,
            maxAgeMs: 10000,
            seenRetentionMs: 20000,
          ),
        );
        await r.engine.onEnvelopeReceived(
          Envelope(
            id: 'old',
            kind: EnvelopeKind.msg,
            fromId: 'A',
            toId: 'Z',
            body: 'stale',
            ts: net.clock,
            ttl: 4,
          ),
          fromPeerId: 'A',
        );
        expect(r.engine.carriedCount, 1);

        net.advanceClock(11000);
        await r.engine.housekeeping();
        expect(r.engine.carriedCount, 0);

        net.advanceClock(30000);
        await r.engine.housekeeping();
        expect(r.seen.entries, isEmpty);
      },
    );
  });

  group('MeshEngine - hello', () {
    test('learns a contact and does not relay the hello', () async {
      final MeshNetwork net = MeshNetwork();
      net.add('A');
      final Node b = net.add('B');
      net.add('C');
      net.connect('A', 'B');
      net.connect('B', 'C');

      await b.engine.onEnvelopeReceived(
        const Envelope(
          id: 'hello-A',
          kind: EnvelopeKind.hello,
          fromId: 'A',
          toId: '',
          body: '',
          ts: 0,
          ttl: 0,
          name: 'Alice',
        ),
        fromPeerId: 'A',
      );
      await net.pump();

      expect(b.delegate.contacts['A'], 'Alice');
      expect(net.nodes['C']!.delegate.contacts, isEmpty);
    });
  });
}
