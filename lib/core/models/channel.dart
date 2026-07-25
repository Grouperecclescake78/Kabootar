import 'dart:math';

/// A broadcast channel (a.k.a. group): a shared room joined with a short random
/// **code** rather than a guessable name. The creator gets a code to share;
/// anyone who enters the same code lands in the same room.
///
/// The channel [id] is derived from the code (`ch_<CODE>`), so no code needs to
/// be exchanged over the mesh - two devices with the same code compute the same
/// id and therefore address the same channel.
class Channel {
  const Channel({required this.id, required this.name, required this.joinedAt});

  final String id;

  /// Display name (the creator's label). May be empty for a channel joined by
  /// code before its name is known - the UI falls back to the code.
  final String name;

  final int joinedAt;

  /// The shareable code, recovered from the id.
  String get code => id.startsWith('ch_') ? id.substring(3) : id;

  /// What to show in lists and headers.
  String get display => name.trim().isEmpty ? '#$code' : name;

  /// The channel id for a given code.
  static String idForCode(String code) =>
      'ch_${code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')}';

  /// A fresh 6-character code using an unambiguous alphabet (no O/0/I/1).
  static String generateCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random rng = Random.secure();
    return List<String>.generate(
      6,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  Channel copyWith({String? name}) =>
      Channel(id: id, name: name ?? this.name, joinedAt: joinedAt);

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'name': name,
        'joined_at': joinedAt,
      };

  static Channel fromRow(Map<String, Object?> row) => Channel(
        id: row['id']! as String,
        name: row['name']! as String,
        joinedAt: (row['joined_at']! as num).toInt(),
      );
}
