/// Someone we have met on the mesh. Learned from a `hello`, not configured by
/// hand - the contact list simply accretes as devices come into range.
class Contact {
  const Contact({
    required this.appId,
    required this.name,
    required this.lastSeen,
    this.online = false,
    this.pubBundle = '',
  });

  /// The peer's stable app id. Primary key.
  final String appId;

  /// Display name from their most recent `hello`.
  final String name;

  /// Epoch milliseconds of the last time we saw them in range.
  final int lastSeen;

  /// The peer's public-key bundle ("<ed>.<x>"), learned from their hello.
  /// Empty for a peer met before encryption existed. Enables E2E encryption.
  final String pubBundle;

  /// Whether this peer is connected right now. Not persisted - it is a live
  /// property of the current transport session, layered on at read time.
  final bool online;

  Contact copyWith({
    String? name,
    int? lastSeen,
    bool? online,
    String? pubBundle,
  }) =>
      Contact(
        appId: appId,
        name: name ?? this.name,
        lastSeen: lastSeen ?? this.lastSeen,
        online: online ?? this.online,
        pubBundle: pubBundle ?? this.pubBundle,
      );

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Map<String, Object?> toRow() => <String, Object?>{
        'app_id': appId,
        'name': name,
        'last_seen': lastSeen,
        'pub_bundle': pubBundle,
      };

  static Contact fromRow(Map<String, Object?> row) => Contact(
        appId: row['app_id']! as String,
        name: row['name']! as String,
        lastSeen: (row['last_seen']! as num).toInt(),
        pubBundle: (row['pub_bundle'] as String?) ?? '',
      );
}
