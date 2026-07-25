import 'package:sqflite/sqflite.dart';

import '../core/models/message.dart';

/// Chat history persistence. Messages are keyed by the wire id, so upserting an
/// incoming message is naturally idempotent even if the mesh delivers a
/// straggler copy that slipped past de-dup on another node.
class MessageRepository {
  MessageRepository(this._db);

  final Database _db;

  Future<void> upsert(Message message) async {
    await _db.insert(
      'messages',
      message.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update just the status of an existing message (e.g. sent -> delivered when
  /// an ack arrives). No-op if the row is gone.
  Future<void> updateStatus(String id, MessageStatus status) async {
    await _db.update(
      'messages',
      <String, Object?>{'status': status.name},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Full conversation with one peer, oldest first.
  Future<List<Message>> conversationWith(String peerId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'messages',
      where: 'peer_id = ?',
      whereArgs: <Object?>[peerId],
      orderBy: 'ts ASC',
    );
    return rows.map(Message.fromRow).toList();
  }

  /// The most recent message per peer - the data behind the conversation list.
  Future<Map<String, Message>> latestPerPeer() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery('''
      SELECT m.* FROM messages m
      JOIN (
        SELECT peer_id, MAX(ts) AS max_ts
        FROM messages GROUP BY peer_id
      ) latest
      ON m.peer_id = latest.peer_id AND m.ts = latest.max_ts
    ''');
    return <String, Message>{
      for (final Map<String, Object?> row in rows)
        row['peer_id']! as String: Message.fromRow(row),
    };
  }

  /// Outgoing messages still awaiting an ack - used to retry/re-flood on
  /// reconnect and to age failed sends.
  Future<List<Message>> undelivered() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'messages',
      where: 'direction = ? AND status IN (?, ?)',
      whereArgs: <Object?>[
        MessageDirection.outgoing.name,
        MessageStatus.sending.name,
        MessageStatus.sent.name,
      ],
    );
    return rows.map(Message.fromRow).toList();
  }
}
