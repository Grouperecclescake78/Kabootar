/// Which way a message travelled relative to this device.
enum MessageDirection { incoming, outgoing }

/// Lifecycle of an outgoing message, mirrored in the chat's status ticks.
///
/// Only end-to-end signals are represented - studchat never claims a state it
/// cannot actually observe:
///   * [sending]   - queued into the mesh, not yet flooded to any peer.
///   * [sent]      - handed to at least one peer; now riding the mesh.
///   * [delivered] - an end-to-end ack came back from the recipient.
///   * [failed]    - gave up (aged out of the carry-cache undelivered).
///
/// Incoming messages are always [delivered].
enum MessageStatus { sending, sent, delivered, failed }

/// A single chat message as stored and shown. Its [id] is the same id the
/// mesh stamps on the wire [Envelope], which is how an incoming ack maps back
/// to the exact row it delivers.
class Message {
  const Message({
    required this.id,
    required this.peerId,
    required this.body,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.senderId,
  });

  /// Matches the wire envelope id. Primary key.
  final String id;

  /// The conversation this message belongs to: for a 1:1 chat it is the *other*
  /// party's app id; for a channel it is the channel id.
  final String peerId;

  final String body;
  final MessageDirection direction;
  final MessageStatus status;

  /// Epoch milliseconds.
  final int timestamp;

  /// For an incoming **channel** message, the app id of whoever sent it (so the
  /// UI can label who said what). Null for 1:1 messages.
  final String? senderId;

  bool get isOutgoing => direction == MessageDirection.outgoing;
  bool get isIncoming => direction == MessageDirection.incoming;

  Message copyWith({MessageStatus? status}) => Message(
        id: id,
        peerId: peerId,
        body: body,
        direction: direction,
        status: status ?? this.status,
        timestamp: timestamp,
        senderId: senderId,
      );

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'peer_id': peerId,
        'body': body,
        'direction': direction.name,
        'status': status.name,
        'ts': timestamp,
        'sender_id': senderId,
      };

  static Message fromRow(Map<String, Object?> row) => Message(
        id: row['id']! as String,
        peerId: row['peer_id']! as String,
        body: row['body']! as String,
        direction: MessageDirection.values.byName(row['direction']! as String),
        status: MessageStatus.values.byName(row['status']! as String),
        timestamp: (row['ts']! as num).toInt(),
        senderId: row['sender_id'] as String?,
      );
}
