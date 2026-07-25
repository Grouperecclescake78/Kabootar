import 'package:sqflite/sqflite.dart';

/// Per-conversation flags: archived, hidden, blocked. Keyed by conversation id
/// (a peer app id for 1:1, or a channel id).
class ConvMetaRepository {
  ConvMetaRepository(this._db);

  final Database _db;

  Future<void> setFlag(String id, String field, bool value) async {
    // Upsert the row, then set the one flag.
    await _db.insert(
      'conv_meta',
      <String, Object?>{'id': id},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _db.update(
      'conv_meta',
      <String, Object?>{field: value ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> remove(String id) async {
    await _db.delete('conv_meta', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Ids currently flagged for [field] (archived / hidden / blocked).
  Future<Set<String>> idsWith(String field) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'conv_meta',
      columns: <String>['id'],
      where: '$field = 1',
    );
    return rows.map((Map<String, Object?> r) => r['id']! as String).toSet();
  }
}
