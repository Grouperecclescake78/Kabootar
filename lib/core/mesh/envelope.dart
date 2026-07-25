import 'dart:convert';

/// The three kinds of unit that travel over the mesh.
///
/// * [hello] - a link-local handshake. Not flooded, not relayed. When two
///   devices form a transport link they trade a [hello] so each learns the
///   other's stable app id and display name (this is how the contact list is
///   built).
/// * [msg]  - a 1:1 chat message addressed to a specific [Envelope.toId].
/// * [ack]  - an end-to-end delivery receipt. Its [Envelope.body] carries the
///   id of the message being acknowledged; it is addressed back to the
///   original sender and flows through the mesh the same way a message does.
enum EnvelopeKind {
  hello,
  msg,
  ack;

  static EnvelopeKind fromWire(String value) {
    switch (value) {
      case 'hello':
        return EnvelopeKind.hello;
      case 'msg':
        return EnvelopeKind.msg;
      case 'ack':
        return EnvelopeKind.ack;
      default:
        throw FormatException('Unknown envelope kind: $value');
    }
  }

  String get wire => name;
}

/// The single unit that crosses the wire. Deliberately tiny and self-describing
/// so any node can route it without shared state: every routing decision the
/// mesh makes is a pure function of these fields.
///
/// Envelopes are immutable. Relaying produces a *new* envelope with a
/// decremented [ttl] via [relayed]; the [id] is preserved so de-duplication
/// still recognises it as the same logical unit at every hop.
class Envelope {
  const Envelope({
    required this.id,
    required this.kind,
    required this.fromId,
    required this.toId,
    required this.body,
    required this.ts,
    required this.ttl,
    this.name = '',
  });

  /// Globally-unique id for this logical unit. The de-dup key. Stable across
  /// every hop - this is what makes epidemic flooding idempotent.
  final String id;

  final EnvelopeKind kind;

  /// Stable app id of the originator.
  final String fromId;

  /// Stable app id of the intended recipient. Empty for a broadcast [hello].
  final String toId;

  /// Chat text for [EnvelopeKind.msg]; the acknowledged message id for
  /// [EnvelopeKind.ack]; empty for [EnvelopeKind.hello].
  final String body;

  /// Originator's send time, epoch milliseconds. Used for age-based pruning.
  final int ts;

  /// Remaining hops. Decremented on each relay; at zero the envelope is
  /// dropped rather than forwarded. Bounds flood radius and storage.
  final int ttl;

  /// Display name - only meaningful on a [hello].
  final String name;

  bool get isHello => kind == EnvelopeKind.hello;
  bool get isMessage => kind == EnvelopeKind.msg;
  bool get isAck => kind == EnvelopeKind.ack;

  /// A copy of this envelope one hop older. Everything is preserved except a
  /// decremented [ttl] - the [id] in particular, so de-dup keeps working.
  Envelope relayed() => Envelope(
    id: id,
    kind: kind,
    fromId: fromId,
    toId: toId,
    body: body,
    ts: ts,
    ttl: ttl - 1,
    name: name,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'k': kind.wire,
    'f': fromId,
    't': toId,
    'b': body,
    'ts': ts,
    'ttl': ttl,
    if (name.isNotEmpty) 'n': name,
  };

  static Envelope fromJson(Map<String, Object?> json) {
    Object? req(String key) {
      final Object? value = json[key];
      if (value == null) throw FormatException('Missing field "$key"');
      return value;
    }

    return Envelope(
      id: req('id')! as String,
      kind: EnvelopeKind.fromWire(req('k')! as String),
      fromId: req('f')! as String,
      toId: (json['t'] as String?) ?? '',
      body: (json['b'] as String?) ?? '',
      ts: (req('ts')! as num).toInt(),
      ttl: (req('ttl')! as num).toInt(),
      name: (json['n'] as String?) ?? '',
    );
  }

  /// Compact wire form sent over the transport.
  String encode() => jsonEncode(toJson());

  /// Parse a wire payload. Throws [FormatException] on anything malformed -
  /// callers on the receive path treat that as a poisoned frame and drop it.
  static Envelope decode(String payload) {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Envelope payload is not a JSON object');
    }
    return fromJson(decoded);
  }

  @override
  bool operator ==(Object other) => other is Envelope && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Envelope(${kind.wire} id=${_short(id)} $fromId->${toId.isEmpty ? '*' : toId} ttl=$ttl)';

  static String _short(String s) => s.length <= 8 ? s : s.substring(0, 8);
}
