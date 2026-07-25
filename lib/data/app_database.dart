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

  static const int _schemaVersion = 3;

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
      onUpgrade: _onUpgrade,
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
        ts         INTEGER NOT NULL,
        sender_id  TEXT,
        delivered_at INTEGER,
        read_at      INTEGER
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

    await _createChannels(db);
  }

  static Future<void> _createChannels(Database db) async {
    await db.execute('''
      CREATE TABLE channels (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        joined_at  INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // v1 -> v2: channels support (broadcast groups) + per-message sender.
    if (from < 2) {
      await _createChannels(db);
      await db.execute('ALTER TABLE messages ADD COLUMN sender_id TEXT');
    }
    // v2 -> v3: delivery + read receipt timestamps for message info.
    if (from < 3) {
      await db.execute('ALTER TABLE messages ADD COLUMN delivered_at INTEGER');
      await db.execute('ALTER TABLE messages ADD COLUMN read_at INTEGER');
    }
  }

  Future<void> close() => db.close();
}
