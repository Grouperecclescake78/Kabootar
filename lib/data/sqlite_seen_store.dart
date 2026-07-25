import 'package:sqflite/sqflite.dart';

import '../core/mesh/mesh_ports.dart';

/// Persistent [SeenStore] backed by SQLite.
///
/// The de-dup set MUST survive restarts: if it did not, a device that rebooted
/// would forget it had already relayed an envelope and re-flood the mesh with
/// it. Persisting `seen` is what makes epidemic routing safe across reboots.
class SqliteSeenStore implements SeenStore {
  SqliteSeenStore(this._db);

  final Database _db;

  @override
  Future<bool> hasSeen(String envelopeId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'seen',
      columns: <String>['id'],
      where: 'id = ?',
      whereArgs: <Object?>[envelopeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> markSeen(String envelopeId, int ts) async {
    await _db.insert('seen', <String, Object?>{
      'id': envelopeId,
      'ts': ts,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> prune(int olderThanTs) async {
    await _db.delete(
      'seen',
      where: 'ts < ?',
      whereArgs: <Object?>[olderThanTs],
    );
  }
}
