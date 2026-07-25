/// Which way a message travelled relative to this device.
enum MessageDirection { incoming, outgoing }

/// Lifecycle of an outgoing message, mirrored in the chat's status ticks.
///
/// Only end-to-end signals are represented - Studchat never claims a state it
/// cannot actually observe:
///   * [sending]   - queued into the mesh, not yet flooded to any peer.
///   * [sent]      - handed to at least one peer; now riding the mesh.
///   * [delivered] - an end-to-end ack came back from the recipient's device.
///   * [read]      - the recipient opened the conversation and saw it.
///   * [failed]    - gave up (aged out of the carry-cache undelivered).
///
/// Incoming messages are always [delivered].
enum MessageStatus { sending, sent, delivered, read, failed }

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
    this.deliveredAt,
    this.readAt,
  });

  /// Matches the wire envelope id. Primary key.
  final String id;

  /// The conversation this message belongs to: for a 1:1 chat it is the *other*
  /// party's app id; for a channel it is the channel id.
  final String peerId;

  final String body;
  final MessageDirection direction;
  final MessageStatus status;

  /// Epoch milliseconds when sent/received.
  final int timestamp;

  /// For an incoming **channel** message, the app id of whoever sent it (so the
  /// UI can label who said what). Null for 1:1 messages.
  final String? senderId;

  /// Epoch milliseconds when a delivery receipt arrived (outgoing only).
  final int? deliveredAt;

  /// Epoch milliseconds when a read receipt arrived (outgoing only).
  final int? readAt;

  bool get isOutgoing => direction == MessageDirection.outgoing;
  bool get isIncoming => direction == MessageDirection.incoming;

  Message copyWith({
    MessageStatus? status,
    int? deliveredAt,
    int? readAt,
  }) =>
      Message(
        id: id,
        peerId: peerId,
        body: body,
        direction: direction,
        status: status ?? this.status,
        timestamp: timestamp,
        senderId: senderId,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        readAt: readAt ?? this.readAt,
      );

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'peer_id': peerId,
        'body': body,
        'direction': direction.name,
        'status': status.name,
        'ts': timestamp,
        'sender_id': senderId,
        'delivered_at': deliveredAt,
        'read_at': readAt,
      };

  static Message fromRow(Map<String, Object?> row) => Message(
        id: row['id']! as String,
        peerId: row['peer_id']! as String,
        body: row['body']! as String,
        direction: MessageDirection.values.byName(row['direction']! as String),
        status: MessageStatus.values.byName(row['status']! as String),
        timestamp: (row['ts']! as num).toInt(),
        senderId: row['sender_id'] as String?,
        deliveredAt: (row['delivered_at'] as num?)?.toInt(),
        readAt: (row['read_at'] as num?)?.toInt(),
      );
}
