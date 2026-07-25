import 'package:sqflite/sqflite.dart';

import '../core/models/contact.dart';

/// Contact-list persistence. The list is not configured by hand - it accretes
/// from `hello` handshakes, so the main operation is an upsert that refreshes a
/// peer's name and last-seen time each time we meet them.
class ContactRepository {
  ContactRepository(this._db);

  final Database _db;

  Future<void> upsert({
    required String appId,
    required String name,
    required int lastSeen,
  }) async {
    await _db.insert('contacts', <String, Object?>{
      'app_id': appId,
      'name': name,
      'last_seen': lastSeen,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> touch(String appId, int lastSeen) async {
    await _db.update(
      'contacts',
      <String, Object?>{'last_seen': lastSeen},
      where: 'app_id = ?',
      whereArgs: <Object?>[appId],
    );
  }

  Future<Contact?> byId(String appId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'contacts',
      where: 'app_id = ?',
      whereArgs: <Object?>[appId],
      limit: 1,
    );
    return rows.isEmpty ? null : Contact.fromRow(rows.first);
  }

  Future<List<Contact>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'contacts',
      orderBy: 'last_seen DESC',
    );
    return rows.map(Contact.fromRow).toList();
  }
}
