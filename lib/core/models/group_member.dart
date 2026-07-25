/// One member of a private group's roster. Carries the member's public-key
/// bundle so their signed group messages can be verified even if we have never
/// met them 1:1.
class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.appId,
    required this.name,
    this.pubBundle = '',
  });

  final String groupId;
  final String appId;
  final String name;
  final String pubBundle;

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
        'group_id': groupId,
        'app_id': appId,
        'name': name,
        'pub_bundle': pubBundle,
      };

  static GroupMember fromRow(Map<String, Object?> row) => GroupMember(
        groupId: row['group_id']! as String,
        appId: row['app_id']! as String,
        name: row['name']! as String,
        pubBundle: (row['pub_bundle'] as String?) ?? '',
      );

  Map<String, Object?> toWire() => <String, Object?>{
        'a': appId,
        'n': name,
        'k': pubBundle,
      };

  static GroupMember fromWire(String groupId, Map<String, Object?> j) =>
      GroupMember(
        groupId: groupId,
        appId: j['a']! as String,
        name: (j['n'] as String?) ?? '',
        pubBundle: (j['k'] as String?) ?? '',
      );
}
