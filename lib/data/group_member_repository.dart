import 'package:sqflite/sqflite.dart';

import '../core/models/group_member.dart';

/// Persistence for private-group rosters.
class GroupMemberRepository {
  GroupMemberRepository(this._db);

  final Database _db;

  Future<void> upsertAll(List<GroupMember> members) async {
    final Batch batch = _db.batch();
    for (final GroupMember m in members) {
      batch.insert(
        'group_members',
        m.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<GroupMember>> forGroup(String groupId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'group_members',
      where: 'group_id = ?',
      whereArgs: <Object?>[groupId],
      orderBy: 'name',
    );
    return rows.map(GroupMember.fromRow).toList();
  }

  Future<List<GroupMember>> all() async {
    final List<Map<String, Object?>> rows = await _db.query('group_members');
    return rows.map(GroupMember.fromRow).toList();
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: <Object?>[groupId],
    );
  }
}
