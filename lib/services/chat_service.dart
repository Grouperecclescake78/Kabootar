import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/identity/identity.dart';
import '../core/mesh/envelope.dart';
import '../core/mesh/mesh_config.dart';
import '../core/mesh/mesh_engine.dart';
import '../core/mesh/mesh_ports.dart';
import '../core/models/channel.dart';
import '../core/models/contact.dart';
import '../core/models/message.dart';
import '../data/app_database.dart';
import '../data/channel_repository.dart';
import '../data/contact_repository.dart';
import '../data/conv_meta_repository.dart';
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
        NearbyTransport(
          deviceName: _shortName(identity.name),
          serviceType: 'studchat',
        );
    _messages = MessageRepository(database.db);
    _contacts = ContactRepository(database.db);
    _channels = ChannelRepository(database.db);
    _convMeta = ConvMetaRepository(database.db);
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
  late final ChannelRepository _channels;
  late final ConvMetaRepository _convMeta;
  late final SqliteSeenStore _seen;
  late final MeshEngine _engine;

  /// How long after sending a message "delete for everyone" stays offered.
  static const int deleteForEveryoneWindowMs = 15 * 60 * 1000;

  Timer? _housekeeping;

  // --- Observable state the UI renders -------------------------------------

  final List<Contact> _contactList = <Contact>[];
  final List<Channel> _channelList = <Channel>[];
  final Map<String, Message> _latestPerPeer = <String, Message>{};
  final List<MeshEvent> _activityLog = <MeshEvent>[];

  /// deviceId -> appId, learned from `hello`; drives the online indicator.
  final Map<String, String> _deviceToApp = <String, String>{};
  final Set<String> _connectedDevices = <String>{};

  /// Incoming message ids we have already sent a read receipt for (in-memory;
  /// a resend after restart is harmless thanks to de-dup on the wire).
  final Set<String> _readReceiptSent = <String>{};

  /// Conversation ids (peer app id or channel id) the user has tucked away.
  /// Archived chats move to a separate section; hidden ones drop out of the
  /// list until they see new activity; blocked ones stop receiving messages.
  final Set<String> _archived = <String>{};
  final Set<String> _hidden = <String>{};
  final Set<String> _blocked = <String>{};

  List<Contact> get contacts => List<Contact>.unmodifiable(_contactList);
  List<Channel> get channels => List<Channel>.unmodifiable(_channelList);
  List<MeshEvent> get activityLog => List<MeshEvent>.unmodifiable(_activityLog);
  int get onlinePeerCount => _connectedDevices.length;
  int get carriedForOthers => _engine.carriedCount;

  Message? latestWith(String appId) => _latestPerPeer[appId];

  bool isOnline(String appId) => _deviceToApp.values.contains(appId);

  /// Whether an id refers to this device (the "Message yourself" conversation).
  bool isSelf(String appId) => appId == identity.appId;

  /// A synthetic contact representing yourself, for the self-notes chat.
  Contact get selfContact => Contact(
        appId: identity.appId,
        name: identity.name.trim().isEmpty ? 'You' : identity.name,
        lastSeen: _nowMs(),
      );

  /// The 1:1 (and self) conversations to show in the Chats list, newest first.
  /// Driven by stored messages, so a conversation stays put even after the
  /// other person disconnects or the app restarts. Archived and hidden chats
  /// are kept out - archived ones live in their own section.
  List<Contact> conversationContacts() => _buildConversations()
      .where((Contact c) => !_archived.contains(c.appId))
      .where((Contact c) => !_hidden.contains(c.appId))
      .toList();

  /// The conversations the user has archived, newest first.
  List<Contact> archivedConversations() => _buildConversations()
      .where((Contact c) => _archived.contains(c.appId))
      .toList();

  int get archivedCount => _archived
      .where((String id) => _latestPerPeer.containsKey(id))
      .where((String id) => !_engine.groupIds.contains(id))
      .length;

  bool isArchived(String id) => _archived.contains(id);
  bool isHidden(String id) => _hidden.contains(id);
  bool isBlocked(String id) => _blocked.contains(id);

  /// Every 1:1 (and self) conversation, newest first, before archive/hide
  /// filtering is applied.
  List<Contact> _buildConversations() {
    final List<Contact> out = <Contact>[];
    for (final MapEntry<String, Message> e in _latestPerPeer.entries) {
      final String id = e.key;
      if (_engine.groupIds.contains(id)) continue; // channels: own tab
      if (id == identity.appId) {
        out.add(selfContact);
        continue;
      }
      Contact? known;
      for (final Contact c in _contactList) {
        if (c.appId == id) {
          known = c;
          break;
        }
      }
      out.add(
        known ??
            Contact(
                appId: id, name: senderLabel(id), lastSeen: e.value.timestamp),
      );
    }
    out.sort(
      (Contact a, Contact b) => latestWith(
        b.appId,
      )!
          .timestamp
          .compareTo(latestWith(a.appId)!.timestamp),
    );
    return out;
  }

  /// Display name for a message sender in a channel: the contact's name if we
  /// know them, our own 'You', or a short id fallback.
  String senderLabel(String appId) {
    if (appId == identity.appId) return 'You';
    for (final Contact c in _contactList) {
      if (c.appId == appId) return c.name;
    }
    return 'Someone (${appId.substring(0, appId.length.clamp(0, 6))})';
  }

  // -------------------------------------------------------------------------

  Future<void> start() async {
    _contactList
      ..clear()
      ..addAll(await _contacts.all());
    _channelList
      ..clear()
      ..addAll(await _channels.all());
    _engine.groupIds.addAll(_channelList.map((Channel c) => c.id));
    _latestPerPeer.addAll(await _messages.latestPerPeer());
    _archived.addAll(await _convMeta.idsWith('archived'));
    _hidden.addAll(await _convMeta.idsWith('hidden'));
    _blocked.addAll(await _convMeta.idsWith('blocked'));

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

  /// Load a full conversation (1:1 or channel) for the chat screen.
  Future<List<Message>> conversation(String peerOrChannelId) =>
      _messages.conversationWith(peerOrChannelId);

  // --- Channels (broadcast groups) -----------------------------------------

  /// Create a new channel with a fresh random code. Share the code so others
  /// can join.
  Future<Channel> createChannel(String name) async {
    final Channel channel = Channel(
      id: Channel.idForCode(Channel.generateCode()),
      name: name.trim(),
      joinedAt: _nowMs(),
    );
    await _addChannel(channel);
    return channel;
  }

  /// Join an existing channel by its code. Returns null if the code is empty.
  Future<Channel?> joinChannelByCode(String code) async {
    final String id = Channel.idForCode(code);
    if (id == 'ch_') return null; // no usable characters
    final Channel channel = Channel(id: id, name: '', joinedAt: _nowMs());
    await _addChannel(channel);
    return channel;
  }

  Future<void> _addChannel(Channel channel) async {
    await _channels.upsert(channel);
    _engine.groupIds.add(channel.id);
    _channelList
      ..removeWhere((Channel c) => c.id == channel.id)
      ..insert(0, channel);
    notifyListeners();
  }

  Future<void> leaveChannel(String id) async {
    await _channels.delete(id);
    _engine.groupIds.remove(id);
    _channelList.removeWhere((Channel c) => c.id == id);
    notifyListeners();
  }

  Channel? channelById(String id) {
    for (final Channel c in _channelList) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Post a message to a channel: flooded to everyone nearby who has joined it.
  /// Best-effort broadcast, so it is marked sent (no per-member ack).
  Future<Message> sendToChannel({
    required String channelId,
    required String body,
  }) async {
    final Envelope envelope = await _engine.sendMessage(
      toId: channelId,
      body: body,
    );
    final Message message = Message(
      id: envelope.id,
      peerId: channelId,
      body: body,
      direction: MessageDirection.outgoing,
      status: MessageStatus.sent,
      timestamp: envelope.ts,
      senderId: identity.appId,
    );
    await _messages.upsert(message);
    _latestPerPeer[channelId] = message;
    notifyListeners();
    return message;
  }

  /// Send a chat message to [toId]. The engine mints the wire envelope; we
  /// persist a row with the same id so an incoming ack can flip it to
  /// delivered.
  Future<Message> send({required String toId, required String body}) async {
    // "Message yourself" is a purely local note: never floods the mesh. You are
    // both sender and reader, so it is delivered and read the instant it is
    // saved (blue double ticks).
    if (toId == identity.appId) {
      final int now = _nowMs();
      final Message note = Message(
        id: _uuid.v4(),
        peerId: identity.appId,
        body: body,
        direction: MessageDirection.outgoing,
        status: MessageStatus.read,
        timestamp: now,
        deliveredAt: now,
        readAt: now,
      );
      await _messages.upsert(note);
      _latestPerPeer[identity.appId] = note;
      notifyListeners();
      return note;
    }

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

  // --- Message & conversation management ------------------------------------

  /// Whether "delete for everyone" should still be offered for [m]: it must be
  /// our own outgoing message (not a self-note) and recently sent.
  bool canDeleteForEveryone(Message m) =>
      m.isOutgoing &&
      !isSelf(m.peerId) &&
      (_nowMs() - m.timestamp) <= deleteForEveryoneWindowMs;

  /// Delete messages for this device only (single or multi-select).
  Future<void> deleteMessages(Iterable<String> ids) async {
    await _messages.deleteMany(ids);
    await _reloadLatest();
    notifyListeners();
  }

  /// Retract one of our own messages everywhere it reached (delete for
  /// everyone): remove it locally and flood a retract so other nodes drop it
  /// too. Best-effort - a peer that is out of range keeps its copy.
  Future<void> deleteForEveryone(Message m) async {
    await _messages.deleteById(m.id);
    await _reloadLatest();
    if (!isSelf(m.peerId)) {
      await _engine.sendRetract(toId: m.peerId, messageId: m.id);
    }
    notifyListeners();
  }

  /// Empty a conversation's history, keeping the contact and any flags.
  Future<void> clearChat(String convId) async {
    await _messages.clearConversation(convId);
    await _reloadLatest();
    notifyListeners();
  }

  /// Remove a conversation entirely: its messages and its archive/hide/block
  /// state. For a channel this also leaves the channel.
  Future<void> deleteChat(String convId) async {
    await _messages.clearConversation(convId);
    await _convMeta.remove(convId);
    _archived.remove(convId);
    _hidden.remove(convId);
    _blocked.remove(convId);
    if (_engine.groupIds.contains(convId)) {
      await leaveChannel(convId);
    }
    await _reloadLatest();
    notifyListeners();
  }

  Future<void> archiveChat(String convId, {required bool archived}) async {
    await _convMeta.setFlag(convId, 'archived', archived);
    _toggle(_archived, convId, archived);
    if (archived) _toggle(_hidden, convId, false); // archive supersedes hide
    if (archived) await _convMeta.setFlag(convId, 'hidden', false);
    notifyListeners();
  }

  Future<void> hideChat(String convId, {required bool hidden}) async {
    await _convMeta.setFlag(convId, 'hidden', hidden);
    _toggle(_hidden, convId, hidden);
    notifyListeners();
  }

  /// Block a contact: stop accepting their incoming messages. The existing
  /// chat stays so it can be unblocked.
  Future<void> blockContact(String appId, {required bool blocked}) async {
    await _convMeta.setFlag(appId, 'blocked', blocked);
    _toggle(_blocked, appId, blocked);
    notifyListeners();
  }

  static void _toggle(Set<String> set, String id, bool present) {
    if (present) {
      set.add(id);
    } else {
      set.remove(id);
    }
  }

  Future<void> _reloadLatest() async {
    _latestPerPeer
      ..clear()
      ..addAll(await _messages.latestPerPeer());
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
    final bool isChannel = _engine.groupIds.contains(message.toId);
    // A channel message belongs to the channel conversation and records who
    // sent it; a 1:1 message belongs to the sender's conversation.
    final String convId = isChannel ? message.toId : message.fromId;
    // A blocked contact's messages are accepted by the mesh but never shown.
    if (!isChannel && _blocked.contains(message.fromId)) return;
    final Message row = Message(
      id: message.id,
      peerId: convId,
      body: message.body,
      direction: MessageDirection.incoming,
      status: MessageStatus.delivered,
      timestamp: message.ts,
      senderId: isChannel ? message.fromId : null,
    );
    await _messages.upsert(row);
    if (!isChannel) {
      await _contacts.touch(message.fromId, _nowMs());
      await _refreshContacts();
    }
    // New activity pulls an archived or hidden conversation back into the list.
    if (_archived.remove(convId)) {
      await _convMeta.setFlag(convId, 'archived', false);
    }
    if (_hidden.remove(convId)) {
      await _convMeta.setFlag(convId, 'hidden', false);
    }
    _latestPerPeer[convId] = row;
    notifyListeners();
  }

  @override
  Future<void> onAckReceived(
      String acknowledgedMessageId, int receiptTs) async {
    await _messages.markDelivered(acknowledgedMessageId, receiptTs);
    _bumpLatest(
      acknowledgedMessageId,
      MessageStatus.delivered,
      deliveredAt: receiptTs,
    );
    notifyListeners();
  }

  @override
  Future<void> onReadReceived(String readMessageId, int receiptTs) async {
    await _messages.markRead(readMessageId, receiptTs);
    _bumpLatest(readMessageId, MessageStatus.read, readAt: receiptTs);
    notifyListeners();
  }

  @override
  Future<void> onRetractReceived(String retractedMessageId) async {
    // The sender deleted this for everyone: drop our copy wherever it lives.
    await _messages.deleteById(retractedMessageId);
    await _reloadLatest();
    notifyListeners();
  }

  /// When the user opens a 1:1 conversation, send read receipts back to the
  /// sender for any of their messages we have not acknowledged as read yet.
  Future<void> markConversationRead(String peerId) async {
    if (peerId == identity.appId || _engine.groupIds.contains(peerId)) return;
    final List<Message> msgs = await _messages.conversationWith(peerId);
    for (final Message m in msgs) {
      if (m.isIncoming && _readReceiptSent.add(m.id)) {
        await _engine.sendReadReceipt(toId: peerId, messageId: m.id);
      }
    }
  }

  /// Update the cached latest-message-per-peer entry for [messageId] to a new
  /// status, never downgrading (read > delivered > sent).
  void _bumpLatest(
    String messageId,
    MessageStatus status, {
    int? deliveredAt,
    int? readAt,
  }) {
    for (final MapEntry<String, Message> e in _latestPerPeer.entries.toList()) {
      if (e.value.id != messageId) continue;
      final bool upgrade = _rank(status) > _rank(e.value.status);
      _latestPerPeer[e.key] = e.value.copyWith(
        status: upgrade ? status : e.value.status,
        deliveredAt: deliveredAt,
        readAt: readAt,
      );
      break;
    }
  }

  static int _rank(MessageStatus s) => switch (s) {
        MessageStatus.sending => 0,
        MessageStatus.sent => 1,
        MessageStatus.delivered => 2,
        MessageStatus.read => 3,
        MessageStatus.failed => -1,
      };

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
      return; // poisoned frame - drop it
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
    if (trimmed.isEmpty) return 'Studchat';
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
