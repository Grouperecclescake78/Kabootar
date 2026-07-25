import 'package:sqflite/sqflite.dart';

import '../core/models/channel.dart';

/// Persistence for joined channels (broadcast groups).
class ChannelRepository {
  ChannelRepository(this._db);

  final Database _db;

  Future<void> upsert(Channel channel) async {
    await _db.insert(
      'channels',
      channel.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('channels', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<Channel>> all() async {
    final List<Map<String, Object?>> rows =
        await _db.query('channels', orderBy: 'joined_at DESC');
    return rows.map(Channel.fromRow).toList();
  }
}
