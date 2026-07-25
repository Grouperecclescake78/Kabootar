/// A broadcast channel (a.k.a. group): a shared room that any nearby device can
/// join by name. Messages posted to a channel are flooded to everyone who has
/// joined it and relayed onward, exactly like a 1:1 message but addressed to the
/// channel id instead of a person.
///
/// The id is a **deterministic** hash of the (normalised) name, so two people
/// who join "studlife" on different phones compute the *same* channel id and
/// therefore see the same room — no id needs to be exchanged.
class Channel {
  const Channel({required this.id, required this.name, required this.joinedAt});

  final String id;
  final String name;
  final int joinedAt;

  /// Compute the stable channel id for a human name. Uses FNV-1a (32-bit) over
  /// the normalised name so the result is identical on every device.
  static String idForName(String name) {
    final String norm = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    int hash = 0x811c9dc5; // FNV offset basis
    for (final int c in norm.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, keep 32-bit
    }
    return 'ch_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// The human-facing display name, always shown with a leading '#'.
  String get display => name.startsWith('#') ? name : '#$name';

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
