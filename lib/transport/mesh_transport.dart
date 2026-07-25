/// A live transport link, identified by the transport's own per-session device
/// id. This id churns on every reconnect - it is deliberately *not* the stable
/// app id the mesh addresses messages to. The mapping between the two is learned
/// from the `hello` handshake.
class TransportPeer {
  const TransportPeer({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;
}

/// What the transport reports upward.
abstract class TransportListener {
  /// A peer link came up. The mesh flushes its carry-cache to this peer.
  void onPeerConnected(TransportPeer peer);

  /// A peer link went down.
  void onPeerDisconnected(String deviceId);

  /// A wire payload arrived from [deviceId]. Always the compact JSON form of an
  /// [Envelope]; the caller decodes and routes it.
  void onPayload(String deviceId, String payload);
}

/// The radio, abstracted. Everything above this line (mesh engine, services) is
/// oblivious to whether the bytes move over Google Nearby, Multipeer, or a fake
/// in a test.
abstract class MeshTransport {
  /// Begin advertising and browsing for nearby peers.
  Future<void> start({required TransportListener listener});

  /// Stop all radio activity and tear down links.
  Future<void> stop();

  /// Currently-connected peers.
  List<TransportPeer> get connectedPeers;

  /// Send one payload to a specific peer.
  Future<void> sendTo(String deviceId, String payload);

  /// Send one payload to every connected peer (epidemic flood).
  Future<void> broadcast(String payload);
}
