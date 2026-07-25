import 'package:studchat/core/mesh/envelope.dart';
import 'package:studchat/core/mesh/mesh_config.dart';
import 'package:studchat/core/mesh/mesh_engine.dart';
import 'package:studchat/core/mesh/mesh_ports.dart';

/// In-memory implementations of the mesh ports plus a tiny network simulator,
/// shared across the engine test suites. All framework-free.

class InMemorySeen implements SeenStore {
  final Map<String, int> entries = <String, int>{};

  @override
  Future<bool> hasSeen(String id) async => entries.containsKey(id);

  @override
  Future<void> markSeen(String id, int ts) async => entries[id] = ts;

  @override
  Future<void> prune(int olderThanTs) async =>
      entries.removeWhere((_, int ts) => ts < olderThanTs);
}

class CollectingDelegate implements MeshDelegate {
  final List<Envelope> delivered = <Envelope>[];
  final List<String> acked = <String>[];
  final Map<String, String> contacts = <String, String>{};
  final List<MeshEvent> events = <MeshEvent>[];

  @override
  Future<void> onMessageDelivered(Envelope message) async =>
      delivered.add(message);

  @override
  Future<void> onAckReceived(String id) async => acked.add(id);

  @override
  Future<void> onHelloReceived(String appId, String name) async =>
      contacts[appId] = name;

  @override
  void onMeshEvent(MeshEvent event) => events.add(event);

  int count(MeshEventType t) =>
      events.where((MeshEvent e) => e.type == t).length;
}

class Node {
  Node(this.id, this.net, {MeshConfig config = MeshConfig.defaults}) {
    engine = MeshEngine(
      myId: id,
      outbound: _Outbound(this),
      seen: seen,
      delegate: delegate,
      clock: () => net.clock,
      newId: net.nextId,
      config: config,
    );
  }

  final String id;
  final MeshNetwork net;
  final InMemorySeen seen = InMemorySeen();
  final CollectingDelegate delegate = CollectingDelegate();
  late final MeshEngine engine;
}

class _Outbound implements MeshOutbound {
  _Outbound(this.node);
  final Node node;

  @override
  void broadcast(Envelope e) {
    for (final String peer in node.net.peersOf(node.id)) {
      node.net._enqueue(peer, e, node.id);
    }
  }

  @override
  void sendTo(String peerId, Envelope e) =>
      node.net._enqueue(peerId, e, node.id);
}

class _Frame {
  _Frame(this.target, this.envelope, this.from);
  final String target;
  final Envelope envelope;
  final String from;
}

class MeshNetwork {
  final Map<String, Node> nodes = <String, Node>{};
  final Set<String> _links = <String>{};
  final List<_Frame> _queue = <_Frame>[];
  int clock = 1000;
  int _idSeq = 0;

  String nextId() => 'id-${_idSeq++}';

  Node add(String id, {MeshConfig config = MeshConfig.defaults}) =>
      nodes[id] = Node(id, this, config: config);

  String _key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  void connect(String a, String b) {
    _links.add(_key(a, b));
    nodes[a]!.engine.onPeerConnected(b);
    nodes[b]!.engine.onPeerConnected(a);
  }

  void disconnect(String a, String b) => _links.remove(_key(a, b));

  Iterable<String> peersOf(String id) =>
      nodes.keys.where((String o) => o != id && _links.contains(_key(id, o)));

  void _enqueue(String target, Envelope e, String from) =>
      _queue.add(_Frame(target, e, from));

  Future<void> pump() async {
    while (_queue.isNotEmpty) {
      final _Frame f = _queue.removeAt(0);
      final Node? target = nodes[f.target];
      if (target == null) continue;
      if (!_links.contains(_key(f.target, f.from))) continue;
      await target.engine.onEnvelopeReceived(f.envelope, fromPeerId: f.from);
    }
  }

  void advanceClock(int ms) => clock += ms;
}
