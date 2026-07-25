import 'package:sqflite/sqflite.dart';

/// Buffers incoming media chunks on disk, keyed by media id, so reassembly
/// survives an app restart mid-transfer.
class MediaChunkRepository {
  MediaChunkRepository(this._db);

  final Database _db;

  Future<void> put({
    required String mediaId,
    required int idx,
    required int total,
    required String data,
  }) async {
    await _db.insert(
      'media_chunks',
      <String, Object?>{
        'media_id': mediaId,
        'idx': idx,
        'total': total,
        'data': data,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> count(String mediaId) async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM media_chunks WHERE media_id = ?',
      <Object?>[mediaId],
    );
    return (r.first['c']! as num).toInt();
  }

  /// The chunk payloads in index order (call once the count is complete).
  Future<List<String>> ordered(String mediaId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'media_chunks',
      columns: <String>['data'],
      where: 'media_id = ?',
      whereArgs: <Object?>[mediaId],
      orderBy: 'idx ASC',
    );
    return rows.map((Map<String, Object?> r) => r['data']! as String).toList();
  }

  Future<void> clear(String mediaId) async {
    await _db.delete(
      'media_chunks',
      where: 'media_id = ?',
      whereArgs: <Object?>[mediaId],
    );
  }

  /// Drop every buffered chunk (called on startup: unfinished transfers are
  /// abandoned since their in-memory reassembly state is gone).
  Future<void> clearAll() async {
    await _db.delete('media_chunks');
  }
}
