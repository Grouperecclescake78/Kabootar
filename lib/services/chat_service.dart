import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/identity/identity.dart';
import '../core/mesh/envelope.dart';
import '../core/mesh/mesh_config.dart';
import '../core/mesh/mesh_engine.dart';
import '../core/mesh/mesh_ports.dart';
import '../core/models/contact.dart';
import '../core/models/message.dart';
import '../data/app_database.dart';
import '../data/contact_repository.dart';
import '../data/identity_store.dart';
import '../data/message_repository.dart';
import '../data/sqlite_seen_store.dart';
import '../transport/mesh_transport.dart';
import '../transport/nearby_transport.dart';

/// The application's single source of truth. It is the seam where the three
/// layers meet: it *is* the mesh engine's [MeshDelegate] and [MeshOutbound],
/// and the transport's [TransportListener]. The UI listens to it and nothing
/// else.
class ChatService extends ChangeNotifier
    implements MeshDelegate, MeshOutbound, TransportListener {
  ChatService({
    required this.identity,
    required AppDatabase database,
    required IdentityStore identityStore,
    MeshTransport? transport,
    MeshConfig config = MeshConfig.defaults,
  })  : _db = database,
        _identityStore = identityStore,
        _config = config {
    _transport = transport ??
        NearbyTransport(deviceName: _shortName(identity.name), serviceType: 'studchat');
    _messages = MessageRepository(database.db);
    _contacts = ContactRepository(database.db);
    _seen = SqliteSeenStore(database.db);
    _engine = MeshEngine(
      myId: identity.appId,
      outbound: this,
      seen: _seen,
      delegate: this,
      clock: _nowMs,
      newId: _uuid.v4,
      config: config,
    );
  }

  Identity identity;

  final AppDatabase _db;
  final IdentityStore _identityStore;
  final MeshConfig _config;
  static const Uuid _uuid = Uuid();

  late final MeshTransport _transport;
  late final MessageRepository _messages;
  late final ContactRepository _contacts;
  late final SqliteSeenStore _seen;
  late final MeshEngine _engine;

  Timer? _housekeeping;

  // --- Observable state the UI renders -------------------------------------

  final List<Contact> _contactList = <Contact>[];
  final Map<String, Message> _latestPerPeer = <String, Message>{};
  final List<MeshEvent> _activityLog = <MeshEvent>[];

  /// deviceId -> appId, learned from `hello`; drives the online indicator.
  final Map<String, String> _deviceToApp = <String, String>{};
  final Set<String> _connectedDevices = <String>{};

  List<Contact> get contacts => List<Contact>.unmodifiable(_contactList);
  List<MeshEvent> get activityLog => List<MeshEvent>.unmodifiable(_activityLog);
  int get onlinePeerCount => _connectedDevices.length;
  int get carriedForOthers => _engine.carriedCount;

  Message? latestWith(String appId) => _latestPerPeer[appId];

  bool isOnline(String appId) => _deviceToApp.values.contains(appId);

  // -------------------------------------------------------------------------

  Future<void> start() async {
    _contactList
      ..clear()
      ..addAll(await _contacts.all());
    _latestPerPeer.addAll(await _messages.latestPerPeer());

    await _transport.start(listener: this);

    // Resume delivery of anything that was still in flight when we last closed:
    // the in-memory carry-cache is gone, but the database remembers.
    for (final Message m in await _messages.undelivered()) {
      await _engine.resumeOutbound(_toEnvelope(m));
    }

    _housekeeping = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _engine.housekeeping(),
    );
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    await _identityStore.setName(name);
    identity = identity.copyWith(name: name);
    notifyListeners();
  }

  /// Load a full conversation for the chat screen.
  Future<List<Message>> conversation(String appId) =>
      _messages.conversationWith(appId);

  /// Send a chat message to [toId]. The engine mints the wire envelope; we
  /// persist a row with the same id so an incoming ack can flip it to
  /// delivered.
  Future<Message> send({required String toId, required String body}) async {
    final Envelope envelope = await _engine.sendMessage(toId: toId, body: body);
    final Message message = Message(
      id: envelope.id,
      peerId: toId,
      body: body,
      direction: MessageDirection.outgoing,
      status: _connectedDevices.isEmpty
          ? MessageStatus.sending
          : MessageStatus.sent,
      timestamp: envelope.ts,
    );
    await _messages.upsert(message);
    _latestPerPeer[toId] = message;
    notifyListeners();
    return message;
  }

  // --- MeshOutbound ---------------------------------------------------------

  @override
  void broadcast(Envelope envelope) {
    unawaited(_transport.broadcast(envelope.encode()));
  }

  @override
  void sendTo(String peerId, Envelope envelope) {
    unawaited(_transport.sendTo(peerId, envelope.encode()));
  }

  // --- MeshDelegate ---------------------------------------------------------

  @override
  Future<void> onMessageDelivered(Envelope message) async {
    final Message row = Message(
      id: message.id,
      peerId: message.fromId,
      body: message.body,
      direction: MessageDirection.incoming,
      status: MessageStatus.delivered,
      timestamp: message.ts,
    );
    await _messages.upsert(row);
    await _contacts.touch(message.fromId, _nowMs());
    _latestPerPeer[message.fromId] = row;
    await _refreshContacts();
    notifyListeners();
  }

  @override
  Future<void> onAckReceived(String acknowledgedMessageId) async {
    await _messages.updateStatus(acknowledgedMessageId, MessageStatus.delivered);
    final Message? current = _latestPerPeer.values
        .where((Message m) => m.id == acknowledgedMessageId)
        .cast<Message?>()
        .firstWhere((Message? m) => true, orElse: () => null);
    if (current != null) {
      _latestPerPeer[current.peerId] =
          current.copyWith(status: MessageStatus.delivered);
    }
    notifyListeners();
  }

  @override
  Future<void> onHelloReceived(String appId, String displayName) async {
    if (appId == identity.appId) return;
    await _contacts.upsert(
      appId: appId,
      name: displayName.isEmpty ? 'Unknown' : displayName,
      lastSeen: _nowMs(),
    );
    await _refreshContacts();
    notifyListeners();
  }

  @override
  void onMeshEvent(MeshEvent event) {
    _activityLog.insert(0, event);
    if (_activityLog.length > 200) _activityLog.removeLast();
    // Cheap events are frequent; coalesce UI updates on the next microtask.
    notifyListeners();
  }

  // --- TransportListener ----------------------------------------------------

  @override
  void onPeerConnected(TransportPeer peer) {
    _connectedDevices.add(peer.deviceId);
    // Introduce ourselves so the peer can map our device link to our app id,
    // then flush anything we are carrying toward its destination.
    sendTo(peer.deviceId, _helloEnvelope());
    _engine.onPeerConnected(peer.deviceId);
    notifyListeners();
  }

  @override
  void onPeerDisconnected(String deviceId) {
    _connectedDevices.remove(deviceId);
    _deviceToApp.remove(deviceId);
    notifyListeners();
  }

  @override
  void onPayload(String deviceId, String payload) {
    final Envelope envelope;
    try {
      envelope = Envelope.decode(payload);
    } on FormatException {
      return; // poisoned frame — drop it
    }
    if (envelope.isHello) {
      _deviceToApp[deviceId] = envelope.fromId;
    }
    unawaited(_engine.onEnvelopeReceived(envelope, fromPeerId: deviceId));
  }

  // -------------------------------------------------------------------------

  Envelope _helloEnvelope() => Envelope(
        id: _uuid.v4(),
        kind: EnvelopeKind.hello,
        fromId: identity.appId,
        toId: '',
        body: '',
        ts: _nowMs(),
        ttl: 0,
        name: identity.name,
      );

  Envelope _toEnvelope(Message m) => Envelope(
        id: m.id,
        kind: EnvelopeKind.msg,
        fromId: identity.appId,
        toId: m.peerId,
        body: m.body,
        ts: m.timestamp,
        ttl: _config.ttl,
      );

  Future<void> _refreshContacts() async {
    _contactList
      ..clear()
      ..addAll(await _contacts.all());
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static String _shortName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return 'studchat';
    return trimmed.length <= 20 ? trimmed : trimmed.substring(0, 20);
  }

  @override
  void dispose() {
    _housekeeping?.cancel();
    unawaited(_transport.stop());
    unawaited(_db.close());
    super.dispose();
  }
}
