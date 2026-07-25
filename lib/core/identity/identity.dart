/// This device's persistent identity on the mesh.
///
/// The [appId] is generated once on first launch and never changes. It is what
/// messages are addressed to - deliberately decoupled from the transport's
/// per-session device id, which churns every time the radio reconnects.
class Identity {
  const Identity({required this.appId, required this.name, this.bio = ''});

  final String appId;
  final String name;

  /// A short "about" line the user writes about themselves. Stored on-device.
  final String bio;

  Identity copyWith({String? name, String? bio}) => Identity(
        appId: appId,
        name: name ?? this.name,
        bio: bio ?? this.bio,
      );
}
