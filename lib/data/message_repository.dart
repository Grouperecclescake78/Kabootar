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

  /// Mark an outgoing message delivered (an ack came back). Does not downgrade
  /// a message that is already read.
  Future<void> markDelivered(String id, int at) async {
    await _db.rawUpdate(
      "UPDATE messages SET status = 'delivered', delivered_at = ? "
      "WHERE id = ? AND status IN ('sending', 'sent')",
      <Object?>[at, id],
    );
  }

  /// Mark an outgoing message read (a read receipt came back), filling in the
  /// delivered time too if it was never separately recorded.
  Future<void> markRead(String id, int at) async {
    await _db.rawUpdate(
      "UPDATE messages SET status = 'read', read_at = ?, "
      "delivered_at = COALESCE(delivered_at, ?) "
      "WHERE id = ? AND status != 'read'",
      <Object?>[at, at, id],
    );
  }

  /// A single message by id, or null.
  Future<Message?> byId(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'messages',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : Message.fromRow(rows.first);
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

  /// Delete a single message by id (delete-for-me, or the local half of a
  /// delete-for-everyone). No-op if already gone.
  Future<void> deleteById(String id) async {
    await _db.delete('messages', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Delete several messages at once (multi-select delete).
  Future<void> deleteMany(Iterable<String> ids) async {
    final List<String> list = ids.toList();
    if (list.isEmpty) return;
    final String marks = List<String>.filled(list.length, '?').join(', ');
    await _db.delete(
      'messages',
      where: 'id IN ($marks)',
      whereArgs: list,
    );
  }

  /// Mark any media still 'receiving' as 'failed'. Called on startup because
  /// reassembly state is in memory and does not survive a restart.
  Future<void> markStaleMediaFailed() async {
    await _db.update(
      'messages',
      <String, Object?>{'media_status': 'failed'},
      where: "media_status = 'receiving'",
    );
  }

  /// Wipe every message in one conversation (clear chat), keeping the contact.
  Future<void> clearConversation(String peerId) async {
    await _db.delete(
      'messages',
      where: 'peer_id = ?',
      whereArgs: <Object?>[peerId],
    );
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
