import 'dart:collection';

import 'envelope.dart';
import 'mesh_config.dart';
import 'mesh_ports.dart';

/// The store-and-forward heart of studchat: a delay-tolerant network using
/// epidemic routing with end-to-end acknowledgements.
///
/// It is deliberately framework-free — no Flutter, no transport plugin, no
/// SQLite. Everything it touches is a port ([MeshOutbound], [SeenStore],
/// [MeshDelegate]) plus an injected clock and id generator, so the entire
/// routing brain runs under plain-Dart unit tests.
///
/// The whole protocol is six rules applied to every envelope that arrives:
///
///   1. **De-dup.** Seen this id before? Drop it. (Stops loops and floods.)
///   2. **Learn.** A `hello` teaches us who a peer is; it is link-local and
///      never relayed.
///   3. **Deliver.** Addressed to us? Persist it and emit an `ack`.
///   4. **Receipt.** An `ack` addressed to us means our message landed.
///   5. **Relay/carry.** Addressed to someone else and `ttl > 0`? Decrement,
///      cache, and flood onward. The envelope now rides this device.
///   6. **Cap.** TTL, max-age, and max-cache-size keep storage bounded; an
///      `ack` we see lets us stop carrying the message it acknowledges.
class MeshEngine {
  MeshEngine({
    required this.myId,
    required MeshOutbound outbound,
    required SeenStore seen,
    required MeshDelegate delegate,
    required MeshClock clock,
    required IdGenerator newId,
    this.config = MeshConfig.defaults,
  })  : _outbound = outbound,
        _seen = seen,
        _delegate = delegate,
        _clock = clock,
        _newId = newId;

  /// This device's stable app id. Messages are addressed to app ids, never to
  /// transport links.
  final String myId;
  final MeshConfig config;

  final MeshOutbound _outbound;
  final SeenStore _seen;
  final MeshDelegate _delegate;
  final MeshClock _clock;
  final IdGenerator _newId;

  /// Envelopes we are carrying on behalf of the mesh, newest last (insertion
  /// order drives oldest-first eviction). Flushed to every new peer.
  final LinkedHashMap<String, Envelope> _carry =
      LinkedHashMap<String, Envelope>();

  /// Read-only view of what we are currently carrying (for diagnostics/UI).
  Iterable<Envelope> get carried => _carry.values;
  int get carriedCount => _carry.length;

  // ---------------------------------------------------------------------------
  // Origination
  // ---------------------------------------------------------------------------

  /// Build and inject a brand-new chat message we are sending. Returns the
  /// [Envelope] so the caller can persist it with a matching id (the message
  /// id and envelope id are the same, which is what lets an incoming ack map
  /// back to the row).
  Future<Envelope> sendMessage({
    required String toId,
    required String body,
  }) async {
    final Envelope envelope = Envelope(
      id: _newId(),
      kind: EnvelopeKind.msg,
      fromId: myId,
      toId: toId,
      body: body,
      ts: _clock(),
      ttl: config.ttl,
    );
    await _inject(envelope);
    return envelope;
  }

  /// Mark, carry, and flood an envelope we originated (a message we sent, or an
  /// ack we emitted). Marking it seen up front means our own echo bouncing back
  /// off a peer is de-duplicated instead of re-processed.
  Future<void> _inject(Envelope envelope) async {
    await _seen.markSeen(envelope.id, envelope.ts);
    _cache(envelope);
    _outbound.broadcast(envelope);
  }

  // ---------------------------------------------------------------------------
  // Receive path — the six rules
  // ---------------------------------------------------------------------------

  /// Process one envelope handed up by the transport.
  Future<void> onEnvelopeReceived(
    Envelope envelope, {
    required String fromPeerId,
  }) async {
    // Rule 2: a hello is link-local. Learn from it, never de-dup or relay it.
    if (envelope.isHello) {
      await _delegate.onHelloReceived(envelope.fromId, envelope.name);
      return;
    }

    // Rule 1: de-dup. This is the single most important line in the protocol.
    if (await _seen.hasSeen(envelope.id)) {
      _emit(MeshEventType.duplicateDropped, envelope);
      return;
    }
    await _seen.markSeen(envelope.id, envelope.ts);
    _emit(MeshEventType.received, envelope);

    // An ack — for anyone — means the message it references has been delivered.
    // Stop carrying that message; no point relaying what already arrived.
    if (envelope.isAck) {
      _clearCarried(envelope.body);
    }

    if (envelope.toId == myId) {
      await _deliverToSelf(envelope);
      return;
    }

    // Rules 5 & 6: addressed to someone else — relay if it still has hops.
    _relay(envelope);
  }

  /// Rules 3 & 4: this envelope is for us.
  Future<void> _deliverToSelf(Envelope envelope) async {
    if (envelope.isAck) {
      // Rule 4: a receipt for a message we sent.
      await _delegate.onAckReceived(envelope.body);
      _emit(MeshEventType.delivered, envelope);
      return;
    }
    // Rule 3: an incoming chat message. Persist, display, then acknowledge.
    await _delegate.onMessageDelivered(envelope);
    _emit(MeshEventType.delivered, envelope);
    await _emitAck(envelope);
  }

  /// Emit an end-to-end delivery receipt addressed back to the sender. The ack
  /// rides the mesh exactly like a message.
  Future<void> _emitAck(Envelope message) async {
    final Envelope ack = Envelope(
      id: _newId(),
      kind: EnvelopeKind.ack,
      fromId: myId,
      toId: message.fromId,
      body: message.id, // the acknowledged message id
      ts: _clock(),
      ttl: config.ttl,
    );
    _emit(MeshEventType.ackEmitted, ack);
    await _inject(ack);
  }

  /// Rules 5 & 6: carry-and-forward on behalf of someone else.
  void _relay(Envelope envelope) {
    if (envelope.ttl <= 0) {
      _emit(MeshEventType.ttlExpired, envelope);
      return;
    }
    final Envelope hopped = envelope.relayed();
    _cache(hopped);
    _outbound.broadcast(hopped);
    _emit(MeshEventType.relayed, hopped);
  }

  // ---------------------------------------------------------------------------
  // Peer lifecycle
  // ---------------------------------------------------------------------------

  /// A new transport link came up. Flush everything we are carrying to that
  /// peer — they will de-dup whatever they already hold. This is the moment a
  /// message that was stranded on this device finally moves closer to its
  /// destination.
  void onPeerConnected(String peerId) {
    if (_carry.isEmpty) return;
    for (final Envelope envelope in _carry.values.toList(growable: false)) {
      _outbound.sendTo(peerId, envelope);
    }
    _emit(
      MeshEventType.cacheFlushed,
      null,
      detail: 'flushed ${_carry.length} carried to $peerId',
    );
  }

  // ---------------------------------------------------------------------------
  // Carry-cache maintenance
  // ---------------------------------------------------------------------------

  void _cache(Envelope envelope) {
    _carry.remove(envelope.id); // re-insert to refresh insertion order
    _carry[envelope.id] = envelope;
    while (_carry.length > config.maxCacheSize) {
      final String oldest = _carry.keys.first;
      _carry.remove(oldest);
      _emit(MeshEventType.cacheEvicted, null, detail: 'evicted $oldest');
    }
  }

  void _clearCarried(String messageId) {
    if (_carry.remove(messageId) != null) {
      _emit(
        MeshEventType.carryCleared,
        null,
        detail: 'stopped carrying $messageId (acked)',
      );
    }
  }

  /// Periodic bounds enforcement: drop carried envelopes older than the max age
  /// and prune ancient de-dup records. Safe to call on a timer.
  Future<void> housekeeping() async {
    final int now = _clock();
    final int ageCutoff = now - config.maxAgeMs;
    final List<String> stale = _carry.entries
        .where((MapEntry<String, Envelope> e) => e.value.ts < ageCutoff)
        .map((MapEntry<String, Envelope> e) => e.key)
        .toList(growable: false);
    for (final String id in stale) {
      _carry.remove(id);
      _emit(MeshEventType.cacheEvicted, null, detail: 'aged out $id');
    }
    await _seen.prune(now - config.seenRetentionMs);
  }

  // ---------------------------------------------------------------------------

  void _emit(MeshEventType type, Envelope? e, {String? detail}) {
    _delegate.onMeshEvent(
      MeshEvent(type, detail ?? e?.toString() ?? '', _clock()),
    );
  }
}
