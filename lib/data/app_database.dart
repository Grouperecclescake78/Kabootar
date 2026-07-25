import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite connection and the schema.
///
/// Three tables mirror the data model in the design:
///   * `contacts` - everyone we have met (learned from `hello`).
///   * `messages` - chat history, keyed by the same id the mesh puts on the wire.
///   * `seen`     - the de-dup set, persisted so a restart cannot re-flood.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int _schemaVersion = 1;

  static Future<AppDatabase> open({String? path}) async {
    final String dbPath =
        path ?? p.join(await getDatabasesPath(), 'studchat.db');
    final Database db = await openDatabase(
      dbPath,
      version: _schemaVersion,
      onConfigure: (Database d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
    return AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        app_id     TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        last_seen  INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id         TEXT PRIMARY KEY,
        peer_id    TEXT NOT NULL,
        body       TEXT NOT NULL,
        direction  TEXT NOT NULL,
        status     TEXT NOT NULL,
        ts         INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_messages_peer_ts ON messages (peer_id, ts)',
    );

    await db.execute('''
      CREATE TABLE seen (
        id  TEXT PRIMARY KEY,
        ts  INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_seen_ts ON seen (ts)');
  }

  Future<void> close() => db.close();
}
