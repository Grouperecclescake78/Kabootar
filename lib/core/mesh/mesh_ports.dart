import 'envelope.dart';

/// The world outside the mesh engine, expressed as narrow interfaces (ports).
///
/// The engine depends only on these abstractions, never on Flutter, the
/// transport plugin, or SQLite. That is what lets the whole store-and-forward
/// core be unit-tested in plain Dart with in-memory fakes.

/// Injectable clock. Real code uses the wall clock; tests drive it by hand so
/// age-based pruning is deterministic.
typedef MeshClock = int Function();

/// Injectable id generator for envelopes the engine creates itself (acks).
/// Tests pass a counter so ids are predictable.
typedef IdGenerator = String Function();

/// Push side of the transport. The engine floods by calling [broadcast]; it
/// flushes its carry-cache to a freshly-connected peer via [sendTo].
abstract class MeshOutbound {
  /// Send [envelope] to every currently-connected peer (epidemic flood).
  void broadcast(Envelope envelope);

  /// Send [envelope] to a single peer by transport id.
  void sendTo(String peerId, Envelope envelope);
}

/// Persistent de-duplication set. An envelope id that has ever been seen is
/// never processed twice - this is what stops loops and flood amplification,
/// and why it must survive restarts.
abstract class SeenStore {
  Future<bool> hasSeen(String envelopeId);
  Future<void> markSeen(String envelopeId, int ts);

  /// Drop de-dup records older than [olderThanTs].
  Future<void> prune(int olderThanTs);
}

/// Everything the engine reports back to the application: chat messages that
/// arrived for us, receipts for messages we sent, contacts we learned about,
/// and a running log of routing decisions so the behaviour stays legible.
abstract class MeshDelegate {
  /// A [EnvelopeKind.msg] addressed to us arrived. Persist and display it.
  Future<void> onMessageDelivered(Envelope message);

  /// A delivery receipt for one of *our* sent messages came back. [receiptTs]
  /// is when the recipient delivered it (the receipt's send time).
  Future<void> onAckReceived(String acknowledgedMessageId, int receiptTs);

  /// A read receipt for one of *our* sent messages came back: the recipient
  /// opened the conversation and saw it. [receiptTs] is when they read it.
  Future<void> onReadReceived(String readMessageId, int receiptTs);

  /// A delete-for-everyone reached us: the sender retracted [retractedMessageId]
  /// and any copy we hold (delivered or still carried) must be removed.
  Future<void> onRetractReceived(String retractedMessageId);

  /// We learned who is on the other end of a link (from a [hello]).
  Future<void> onHelloReceived(String appId, String displayName);

  /// A routing decision worth surfacing (relay, drop, cap hit, delivery).
  void onMeshEvent(MeshEvent event);
}

/// Categories of routing decision, for the in-app activity log.
enum MeshEventType {
  received,
  duplicateDropped,
  delivered,
  relayed,
  ttlExpired,
  cacheEvicted,
  ackEmitted,
  carryCleared,
  cacheFlushed,
}

/// A single legible line in the mesh's activity log.
class MeshEvent {
  const MeshEvent(this.type, this.detail, this.ts);

  final MeshEventType type;
  final String detail;
  final int ts;

  @override
  String toString() => '[$type] $detail';
}
