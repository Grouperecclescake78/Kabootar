import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/app_keys.dart';
import '../core/identity/identity.dart';
import '../core/media/media_codec.dart';
import '../core/mesh/envelope.dart';
import '../core/mesh/mesh_config.dart';
import '../core/mesh/mesh_engine.dart';
import '../core/mesh/mesh_ports.dart';
import '../core/models/channel.dart';
import '../core/models/contact.dart';
import '../core/models/group_member.dart';
import '../core/models/message.dart';
import '../data/app_database.dart';
import '../data/channel_repository.dart';
import '../data/contact_repository.dart';
import '../data/conv_meta_repository.dart';
import '../data/group_member_repository.dart';
import '../data/identity_store.dart';
import '../data/media_chunk_repository.dart';
import '../data/message_repository.dart';
import '../data/sqlite_seen_store.dart';
import '../transport/mesh_transport.dart';
import '../transport/nearby_transport.dart';
import 'notification_service.dart';

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
    NotificationService? notifications,
    AppKeys? keys,
    MeshConfig config = MeshConfig.defaults,
  })  : _db = database,
        _identityStore = identityStore,
        _notifications = notifications,
        _keys = keys,
        _config = config {
    _transport = transport ??
        NearbyTransport(
          deviceName: _shortName(identity.name),
          serviceType: 'kabootar',
        );
    _messages = MessageRepository(database.db);
    _contacts = ContactRepository(database.db);
    _channels = ChannelRepository(database.db);
    _groupMembers = GroupMemberRepository(database.db);
    _mediaChunks = MediaChunkRepository(database.db);
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
  final NotificationService? _notifications;

  /// This device's E2E key material (null disables encryption, e.g. in tests).
  final AppKeys? _keys;

  /// Peer app id -> their public keys, learned from hellos. When we hold a
  /// peer's keys, 1:1 messages to and from them are encrypted and signed.
  final Map<String, PeerKeys> _peerKeys = <String, PeerKeys>{};

  final MeshConfig _config;
  static const Uuid _uuid = Uuid();

  /// Whether the app is currently in the foreground, and which conversation (if
  /// any) is open on screen. Together they decide when an incoming message
  /// should raise a notification: we stay quiet only while the user is actually
  /// looking at that conversation. Updated by the app shell and chat screens.
  bool appResumed = true;
  String? openConversationId;

  late final MeshTransport _transport;
  late final MessageRepository _messages;
  late final ContactRepository _contacts;
  late final ChannelRepository _channels;
  late final GroupMemberRepository _groupMembers;
  late final MediaChunkRepository _mediaChunks;
  late final ConvMetaRepository _convMeta;
  late final SqliteSeenStore _seen;
  late final MeshEngine _engine;

  /// Where downloaded media files are written (lazy, cached).
  Directory? _mediaDir;

  /// Private-group id -> its member roster (kept in memory for the UI).
  final Map<String, List<GroupMember>> _groupRosters =
      <String, List<GroupMember>>{};

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

  /// Conversations with unread activity: set when a message arrives while you
  /// are not looking at them, or manually via "mark as unread"; cleared when
  /// you open the chat.
  final Set<String> _unread = <String>{};

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

  /// The conversations the user has hidden, newest first. Reachable from the
  /// profile sheet so a hidden chat can always be found and unhidden.
  List<Contact> hiddenConversations() => _buildConversations()
      .where((Contact c) =>
          _hidden.contains(c.appId) && !_archived.contains(c.appId))
      .toList();

  int get hiddenCount => _hidden
      .where((String id) => _latestPerPeer.containsKey(id))
      .where((String id) => !_engine.groupIds.contains(id))
      .where((String id) => !_archived.contains(id))
      .length;

  bool isArchived(String id) => _archived.contains(id);
  bool isHidden(String id) => _hidden.contains(id);
  bool isBlocked(String id) => _blocked.contains(id);
  bool isUnread(String id) => _unread.contains(id);

  /// How many conversations are currently unread (for a tab badge).
  int get unreadCount => _unread.length;

  /// Manually flag or clear a conversation's unread state.
  Future<void> setUnread(String convId, {required bool unread}) async {
    if (unread) {
      if (!_unread.add(convId)) return;
    } else if (!_unread.remove(convId)) {
      return;
    }
    await _convMeta.setFlag(convId, 'unread', unread);
    notifyListeners();
  }

  /// Called when a conversation is opened: clears its unread flag.
  Future<void> clearUnread(String convId) async {
    if (!_unread.remove(convId)) return;
    await _convMeta.setFlag(convId, 'unread', false);
    notifyListeners();
  }

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
    _loadPeerKeys();
    _channelList
      ..clear()
      ..addAll(await _channels.all());
    _engine.groupIds.addAll(_channelList.map((Channel c) => c.id));
    await _loadRosters();
    _latestPerPeer.addAll(await _messages.latestPerPeer());
    _archived.addAll(await _convMeta.idsWith('archived'));
    _hidden.addAll(await _convMeta.idsWith('hidden'));
    _blocked.addAll(await _convMeta.idsWith('blocked'));
    _unread.addAll(await _convMeta.idsWith('unread'));
    // Media reassembly is in-memory, so any transfer caught mid-flight by the
    // last shutdown is abandoned rather than left half-done.
    await _messages.markStaleMediaFailed();
    await _mediaChunks.clearAll();

    await _transport.start(listener: this);

    // Resume delivery of anything that was still in flight when we last closed:
    // the in-memory carry-cache is gone, but the database remembers. Rebuild
    // each envelope through the same path as a fresh send, so an undelivered
    // message to an encrypted peer is re-sealed rather than leaked as plaintext.
    for (final Message m in await _messages.undelivered()) {
      await _engine.resumeOutbound(
        await _buildOutgoing(
          id: m.id,
          toId: m.peerId,
          plaintext: m.body,
          ts: m.timestamp,
        ),
      );
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

  Future<void> updateBio(String bio) async {
    await _identityStore.setBio(bio);
    identity = identity.copyWith(bio: bio);
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
    await _groupMembers.deleteGroup(id);
    _groupRosters.remove(id);
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

  // --- Private groups (invite-only, encrypted) -----------------------------

  bool isPrivateGroup(String id) => channelById(id)?.isPrivate ?? false;

  /// The roster of a private group, for the members screen.
  List<GroupMember> groupMembers(String id) => List<GroupMember>.unmodifiable(
      _groupRosters[id] ?? const <GroupMember>[]);

  /// Contacts who can be invited to [groupId]: ones whose keys we hold and who
  /// are not already members.
  List<Contact> invitableContacts(String groupId) {
    final Set<String> members =
        (_groupRosters[groupId] ?? const <GroupMember>[])
            .map((GroupMember m) => m.appId)
            .toSet();
    return _contactList
        .where((Contact c) => _peerKeys.containsKey(c.appId))
        .where((Contact c) => !members.contains(c.appId))
        .toList();
  }

  /// Create a new private group. A fresh symmetric key is minted and we become
  /// its first member; others join only by an encrypted invite.
  Future<Channel> createPrivateGroup(String name) async {
    final String key = await AppKeys.newGroupKey();
    final Channel channel = Channel(
      id: Channel.privateGroupId(_uuid.v4()),
      name: name.trim(),
      joinedAt: _nowMs(),
      isPrivate: true,
      groupKey: key,
    );
    await _channels.upsert(channel);
    _engine.groupIds.add(channel.id);
    _channelList.insert(0, channel);
    final GroupMember me = GroupMember(
      groupId: channel.id,
      appId: identity.appId,
      name: _selfName,
      pubBundle: _keys?.publicBundle ?? '',
    );
    await _groupMembers.upsertAll(<GroupMember>[me]);
    _groupRosters[channel.id] = <GroupMember>[me];
    notifyListeners();
    return channel;
  }

  /// Invite a contact to a private group: add them to the roster and send them
  /// an encrypted invite (group id, name, key, roster) sealed to their key.
  Future<bool> inviteToGroup(String groupId, Contact contact) async {
    final AppKeys? keys = _keys;
    final PeerKeys? pk = _peerKeys[contact.appId];
    final Channel? group = channelById(groupId);
    if (keys == null || pk == null || group == null || !group.isPrivate) {
      return false;
    }

    final GroupMember invitee = GroupMember(
      groupId: groupId,
      appId: contact.appId,
      name: contact.name,
      pubBundle: contact.pubBundle,
    );
    final List<GroupMember> roster = <GroupMember>[
      ...?_groupRosters[groupId],
      if (!(_groupRosters[groupId] ?? const <GroupMember>[])
          .any((GroupMember m) => m.appId == contact.appId))
        invitee,
    ];
    await _groupMembers.upsertAll(<GroupMember>[invitee]);
    _groupRosters[groupId] = roster;

    final String payload = jsonEncode(<String, Object?>{
      'g': groupId,
      'n': group.name,
      'k': group.groupKey,
      'm': roster.map((GroupMember m) => m.toWire()).toList(),
    });
    final String id = _uuid.v4();
    final int ts = _nowMs();
    final String blob = await keys.seal(pk.agree, utf8.encode(payload));
    final String sig = await keys.signB64(
      _signedBytes(
        id: id,
        from: identity.appId,
        to: contact.appId,
        ts: ts,
        body: blob,
      ),
    );
    await _engine.enqueueOutbound(
      Envelope(
        id: id,
        kind: EnvelopeKind.invite,
        fromId: identity.appId,
        toId: contact.appId,
        body: blob,
        ts: ts,
        ttl: _config.ttl,
        enc: true,
        sig: sig,
      ),
    );
    notifyListeners();
    return true;
  }

  String get _selfName =>
      identity.name.trim().isEmpty ? 'You' : identity.name.trim();

  Future<void> _loadRosters() async {
    _groupRosters.clear();
    for (final GroupMember m in await _groupMembers.all()) {
      (_groupRosters[m.groupId] ??= <GroupMember>[]).add(m);
      final PeerKeys? pk = AppKeys.parseBundle(m.pubBundle);
      if (pk != null) _peerKeys.putIfAbsent(m.appId, () => pk);
    }
  }

  /// Post a message to a channel or private group: flooded to everyone nearby
  /// who has joined it. Best-effort broadcast, so it is marked sent (no
  /// per-member ack). In a private group the body is sealed with the group key
  /// and signed, so only members can read it.
  Future<Message> sendToChannel({
    required String channelId,
    required String body,
  }) async {
    final Channel? group = channelById(channelId);
    final String id = _uuid.v4();
    final int ts = _nowMs();
    Envelope envelope;
    if (group != null &&
        group.isPrivate &&
        group.groupKey.isNotEmpty &&
        _keys != null) {
      final String blob = await AppKeys.sealSym(
        group.groupKey,
        utf8.encode(body),
      );
      final String sig = await _keys.signB64(
        _signedBytes(
          id: id,
          from: identity.appId,
          to: channelId,
          ts: ts,
          body: blob,
        ),
      );
      envelope = Envelope(
        id: id,
        kind: EnvelopeKind.msg,
        fromId: identity.appId,
        toId: channelId,
        body: blob,
        ts: ts,
        ttl: _config.ttl,
        enc: true,
        sig: sig,
      );
    } else {
      envelope = Envelope(
        id: id,
        kind: EnvelopeKind.msg,
        fromId: identity.appId,
        toId: channelId,
        body: body,
        ts: ts,
        ttl: _config.ttl,
      );
    }
    await _engine.enqueueOutbound(envelope);
    final Message message = Message(
      id: id,
      peerId: channelId,
      body: body,
      direction: MessageDirection.outgoing,
      status: MessageStatus.sent,
      timestamp: ts,
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

    // Build the wire envelope (encrypted + signed when we hold the peer's
    // keys) and inject it. We keep the plaintext locally for display; only the
    // ciphertext ever crosses the mesh.
    final String id = _uuid.v4();
    final int ts = _nowMs();
    final Envelope envelope = await _buildOutgoing(
      id: id,
      toId: toId,
      plaintext: body,
      ts: ts,
    );
    await _engine.enqueueOutbound(envelope);
    final Message message = Message(
      id: id,
      peerId: toId,
      body: body,
      direction: MessageDirection.outgoing,
      status: _connectedDevices.isEmpty
          ? MessageStatus.sending
          : MessageStatus.sent,
      timestamp: ts,
    );
    await _messages.upsert(message);
    _latestPerPeer[toId] = message;
    notifyListeners();
    return message;
  }

  /// Build a 1:1 outgoing message envelope. When we hold the recipient's keys
  /// (and it is a real peer, not a channel or self), the body is sealed to
  /// their X25519 key and signed with our Ed25519 key; otherwise it goes as
  /// plaintext, exactly as before encryption existed.
  Future<Envelope> _buildOutgoing({
    required String id,
    required String toId,
    required String plaintext,
    required int ts,
  }) async {
    final AppKeys? keys = _keys;
    final PeerKeys? peer = _peerKeys[toId];
    final bool encryptable = keys != null &&
        peer != null &&
        toId != identity.appId &&
        !_engine.groupIds.contains(toId);
    if (encryptable) {
      final String blob = await keys.seal(peer.agree, utf8.encode(plaintext));
      final String sig = await keys.signB64(
        _signedBytes(
            id: id, from: identity.appId, to: toId, ts: ts, body: blob),
      );
      return Envelope(
        id: id,
        kind: EnvelopeKind.msg,
        fromId: identity.appId,
        toId: toId,
        body: blob,
        ts: ts,
        ttl: _config.ttl,
        enc: true,
        sig: sig,
      );
    }
    return Envelope(
      id: id,
      kind: EnvelopeKind.msg,
      fromId: identity.appId,
      toId: toId,
      body: plaintext,
      ts: ts,
      ttl: _config.ttl,
    );
  }

  /// Canonical bytes an encrypted message's signature covers: the immutable
  /// routing fields plus the ciphertext. TTL is excluded because relays change
  /// it. Binding the ids and ciphertext stops tampering and impersonation.
  List<int> _signedBytes({
    required String id,
    required String from,
    required String to,
    required int ts,
    required String body,
  }) =>
      utf8.encode('$id|$from|$to|$ts|$body');

  void _loadPeerKeys() {
    _peerKeys.clear();
    for (final Contact c in _contactList) {
      final PeerKeys? pk = AppKeys.parseBundle(c.pubBundle);
      if (pk != null) _peerKeys[c.appId] = pk;
    }
  }

  /// Whether messages with [appId] are end-to-end encrypted (we hold their
  /// keys). Drives the lock indicator in the chat UI.
  bool isEncryptedWith(String appId) =>
      _keys != null && appId != identity.appId && _peerKeys.containsKey(appId);

  /// A shared safety code both people can compare out-of-band to confirm there
  /// is no man-in-the-middle. Null until we have the peer's keys.
  Future<String>? safetyCodeWith(String appId) {
    final AppKeys? keys = _keys;
    final Contact? c = _contactById(appId);
    if (keys == null || c == null || c.pubBundle.isEmpty) return null;
    final List<String> bundles = <String>[keys.publicBundle, c.pubBundle]
      ..sort();
    return AppKeys.fingerprint(bundles.join('|'));
  }

  Contact? _contactById(String appId) {
    for (final Contact c in _contactList) {
      if (c.appId == appId) return c;
    }
    return null;
  }

  // --- Media (images) ------------------------------------------------------

  /// Tracks an in-flight incoming media transfer (reassembly state). Lives only
  /// for the session; a restart marks any unfinished media failed.
  final Map<String, _IncomingMedia> _incomingMedia = <String, _IncomingMedia>{};

  Future<Directory> _mediaDirectory() async {
    final Directory d = _mediaDir ??= Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'media'),
    );
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  /// Send a picked image: compress it and make a thumbnail (in a background
  /// isolate, so decoding a large photo does not jank the UI), then hand it to
  /// the shared media path (encrypt, chunk, flood).
  Future<void> sendImage({
    required String convId,
    required Uint8List bytes,
    String name = 'photo.jpg',
  }) async {
    final List<Uint8List> out = await compute(MediaCodec.imageAndThumb, bytes);
    await _sendMedia(
      convId: convId,
      kind: 'image',
      name: name,
      mime: 'image/jpeg',
      fileBytes: out[0],
      thumbBytes: out[1],
      ext: 'jpg',
    );
  }

  /// Send an arbitrary file over the same chunked media path (no compression or
  /// thumbnail).
  Future<void> sendFile({
    required String convId,
    required Uint8List bytes,
    required String name,
    String mime = 'application/octet-stream',
  }) =>
      _sendMedia(
        convId: convId,
        kind: 'file',
        name: name,
        mime: mime,
        fileBytes: bytes,
        ext: p.extension(name).replaceFirst('.', ''),
      );

  /// The shared media send path: store the local copy immediately, then
  /// encrypt (to the peer or group key, or plaintext on an open channel), split
  /// into chunks and flood a manifest plus the chunks.
  Future<void> _sendMedia({
    required String convId,
    required String kind,
    required String name,
    required String mime,
    required Uint8List fileBytes,
    required String ext,
    Uint8List? thumbBytes,
  }) async {
    final String mediaId = _uuid.v4();
    final int ts = _nowMs();
    final String fileName = ext.isEmpty ? mediaId : '$mediaId.$ext';
    final File file = File(p.join((await _mediaDirectory()).path, fileName));
    await file.writeAsBytes(fileBytes);

    final Message row = Message(
      id: mediaId,
      peerId: convId,
      body: '',
      direction: MessageDirection.outgoing,
      status: _connectedDevices.isEmpty
          ? MessageStatus.sending
          : MessageStatus.sent,
      timestamp: ts,
      senderId: _engine.groupIds.contains(convId) ? identity.appId : null,
      mediaKind: kind,
      mediaName: name,
      mediaMime: mime,
      mediaPath: file.path,
      mediaBytes: fileBytes.length,
      mediaStatus: 'complete',
      thumb: thumbBytes == null ? null : base64Url.encode(thumbBytes),
    );
    await _messages.upsert(row);
    _latestPerPeer[convId] = row;
    notifyListeners();

    if (convId == identity.appId) return; // self note: nothing to flood

    final (String fullB64, bool enc) = await _encryptConv(convId, fileBytes);
    final String thumbCipher =
        thumbBytes == null ? '' : (await _encryptConv(convId, thumbBytes)).$1;
    final List<String> chunks = MediaCodec.chunk(fullB64);
    final String manifest = jsonEncode(<String, Object?>{
      'k': kind,
      'n': name,
      'm': mime,
      'x': ext,
      'b': fileBytes.length,
      'c': chunks.length,
      'e': enc ? 1 : 0,
      't': thumbCipher,
    });
    final String sig = _keys == null
        ? ''
        : await _keys.signB64(_signedBytes(
            id: mediaId,
            from: identity.appId,
            to: convId,
            ts: ts,
            body: manifest,
          ));
    await _engine.enqueueOutbound(Envelope(
      id: mediaId,
      kind: EnvelopeKind.media,
      fromId: identity.appId,
      toId: convId,
      body: manifest,
      ts: ts,
      ttl: _config.ttl,
      sig: sig,
    ));
    for (int i = 0; i < chunks.length; i++) {
      await _engine.enqueueOutbound(Envelope(
        id: '$mediaId#$i',
        kind: EnvelopeKind.chunk,
        fromId: identity.appId,
        toId: convId,
        body: '$mediaId|$i|${chunks.length}|${chunks[i]}',
        ts: ts,
        ttl: _config.ttl,
      ));
    }
  }

  /// Encrypt [bytes] for a conversation, mirroring the text path. Returns the
  /// base64 payload and whether it was encrypted.
  Future<(String, bool)> _encryptConv(String convId, List<int> bytes) async {
    final Channel? group = channelById(convId);
    if (group != null && group.isPrivate && group.groupKey.isNotEmpty) {
      return (await AppKeys.sealSym(group.groupKey, bytes), true);
    }
    final PeerKeys? peer = _peerKeys[convId];
    if (_keys != null && peer != null && !_engine.groupIds.contains(convId)) {
      return (await _keys.seal(peer.agree, bytes), true);
    }
    return (base64Url.encode(bytes), false);
  }

  /// Decrypt a received media payload using the transfer's recorded mode.
  Future<Uint8List?> _decryptPayload(_IncomingMedia meta, String b64) async {
    if (b64.isEmpty) return null;
    if (!meta.enc) {
      try {
        return Uint8List.fromList(base64Url.decode(b64));
      } catch (_) {
        return null;
      }
    }
    final Channel? group = channelById(meta.convId);
    if (group != null && group.isPrivate && group.groupKey.isNotEmpty) {
      final List<int>? c = await AppKeys.openSym(group.groupKey, b64);
      return c == null ? null : Uint8List.fromList(c);
    }
    final PeerKeys? peer = _peerKeys[meta.fromId];
    if (_keys != null && peer != null) {
      final List<int>? c = await _keys.open(peer.agree, b64);
      return c == null ? null : Uint8List.fromList(c);
    }
    return null; // encrypted but we lack the key
  }

  @override
  Future<void> onMediaReceived(Envelope manifest) async {
    final bool isChannel = _engine.groupIds.contains(manifest.toId);
    final String convId = isChannel ? manifest.toId : manifest.fromId;
    if (!isChannel && _blocked.contains(manifest.fromId)) return;

    final PeerKeys? sender = _peerKeys[manifest.fromId];
    if (sender != null && manifest.sig.isNotEmpty) {
      final bool ok = await AppKeys.verifyB64(
        _signedBytes(
          id: manifest.id,
          from: manifest.fromId,
          to: manifest.toId,
          ts: manifest.ts,
          body: manifest.body,
        ),
        manifest.sig,
        sender.sign,
      );
      if (!ok) return; // forged manifest
    }

    final Map<String, Object?> j =
        jsonDecode(manifest.body) as Map<String, Object?>;
    final String mediaId = manifest.id;
    final int total = (j['c'] as num?)?.toInt() ?? 0;
    final String kind = (j['k'] as String?) ?? 'image';
    final _IncomingMedia meta = _IncomingMedia(
      enc: (j['e'] as num?)?.toInt() == 1,
      convId: convId,
      fromId: manifest.fromId,
      total: total,
      ext: (j['x'] as String?) ?? (kind == 'image' ? 'jpg' : ''),
    );
    _incomingMedia[mediaId] = meta;
    final Uint8List? thumbBytes =
        await _decryptPayload(meta, (j['t'] as String?) ?? '');

    final Message row = Message(
      id: mediaId,
      peerId: convId,
      body: '',
      direction: MessageDirection.incoming,
      status: MessageStatus.delivered,
      timestamp: manifest.ts,
      senderId: isChannel ? manifest.fromId : null,
      mediaKind: kind,
      mediaName:
          (j['n'] as String?) ?? (kind == 'image' ? 'photo.jpg' : 'file'),
      mediaMime: (j['m'] as String?) ??
          (kind == 'image' ? 'image/jpeg' : 'application/octet-stream'),
      mediaBytes: (j['b'] as num?)?.toInt(),
      mediaStatus: 'receiving',
      thumb: thumbBytes == null ? '' : base64Url.encode(thumbBytes),
    );
    await _messages.upsert(row);
    if (!isChannel) {
      await _contacts.touch(manifest.fromId, _nowMs());
      await _refreshContacts();
    }
    if (_archived.remove(convId)) {
      await _convMeta.setFlag(convId, 'archived', false);
    }
    if (_hidden.remove(convId)) {
      await _convMeta.setFlag(convId, 'hidden', false);
    }
    _latestPerPeer[convId] = row;
    _markUnreadIfAway(convId);
    _maybeNotify(
      isChannel: isChannel,
      convId: convId,
      sender: senderLabel(manifest.fromId),
      body: kind == 'image' ? '📷 Photo' : '📎 File',
    );
    notifyListeners();
    await _tryReassemble(mediaId);
  }

  @override
  Future<void> onChunkReceived(Envelope chunk) async {
    final List<String> parts = chunk.body.split('|');
    if (parts.length < 4) return;
    final String mediaId = parts[0];
    final int idx = int.tryParse(parts[1]) ?? -1;
    final int total = int.tryParse(parts[2]) ?? 0;
    if (idx < 0) return;
    // base64url never contains '|', but rejoin defensively.
    final String data = parts.sublist(3).join('|');
    await _mediaChunks.put(
      mediaId: mediaId,
      idx: idx,
      total: total,
      data: data,
    );
    if (_incomingMedia.containsKey(mediaId)) await _tryReassemble(mediaId);
  }

  Future<void> _tryReassemble(String mediaId) async {
    final _IncomingMedia? meta = _incomingMedia[mediaId];
    if (meta == null || meta.total <= 0) return;
    if (await _mediaChunks.count(mediaId) < meta.total) return;

    final String cipherB64 =
        MediaCodec.join(await _mediaChunks.ordered(mediaId));
    final Uint8List? bytes = await _decryptPayload(meta, cipherB64);
    final Message? msg = await _messages.byId(mediaId);
    if (bytes == null) {
      if (msg != null) {
        await _messages.upsert(msg.copyWith(mediaStatus: 'failed'));
      }
    } else {
      final String fileName =
          meta.ext.isEmpty ? mediaId : '$mediaId.${meta.ext}';
      final File file = File(p.join((await _mediaDirectory()).path, fileName));
      await file.writeAsBytes(bytes);
      if (msg != null) {
        await _messages.upsert(
          msg.copyWith(mediaStatus: 'complete', mediaPath: file.path),
        );
      }
    }
    await _mediaChunks.clear(mediaId);
    _incomingMedia.remove(mediaId);
    await _reloadLatest();
    notifyListeners();
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

    // Decrypt and authenticate an encrypted message. A message that fails to
    // verify with a known key is forged or tampered, so we drop it; if we
    // simply do not have the sender's key yet, we keep a visible placeholder so
    // nothing silently disappears.
    String bodyText = message.body;
    if (message.enc) {
      final String? plain = isChannel
          ? await _openGroupMessage(message)
          : await _openDirectMessage(message);
      if (plain == null) return; // forged or undecipherable
      bodyText = plain;
    }

    final Message row = Message(
      id: message.id,
      peerId: convId,
      body: bodyText,
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
    _markUnreadIfAway(convId);
    _maybeNotify(
      isChannel: isChannel,
      convId: convId,
      sender: senderLabel(message.fromId),
      body: bodyText,
    );
    notifyListeners();
  }

  /// Flag a conversation unread when a message lands there while the user is
  /// looking elsewhere.
  void _markUnreadIfAway(String convId) {
    if (appResumed && openConversationId == convId) return;
    if (_unread.add(convId)) {
      unawaited(_convMeta.setFlag(convId, 'unread', true));
    }
  }

  /// Raise a notification for an incoming message (already decrypted) unless the
  /// user is currently looking at that conversation.
  void _maybeNotify({
    required bool isChannel,
    required String convId,
    required String sender,
    required String body,
  }) {
    final bool viewing = appResumed && openConversationId == convId;
    if (viewing) return;
    final String title =
        isChannel ? (channelById(convId)?.display ?? 'Channel') : sender;
    final String text = isChannel ? '$sender: $body' : body;
    unawaited(
      _notifications?.showMessage(title: title, body: text, threadKey: convId),
    );
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

  @override
  Future<void> onInviteReceived(Envelope invite) async {
    // An encrypted private-group invite sealed to us. Verify the inviter, open
    // the payload, and join the group (store its key + roster).
    final AppKeys? keys = _keys;
    final PeerKeys? inviter = _peerKeys[invite.fromId];
    if (keys == null || inviter == null) return; // cannot authenticate inviter
    final bool ok = await AppKeys.verifyB64(
      _signedBytes(
        id: invite.id,
        from: invite.fromId,
        to: invite.toId,
        ts: invite.ts,
        body: invite.body,
      ),
      invite.sig,
      inviter.sign,
    );
    if (!ok) return;
    final List<int>? clear = await keys.open(inviter.agree, invite.body);
    if (clear == null) return;

    final Map<String, Object?> j =
        (jsonDecode(utf8.decode(clear)) as Map<String, Object?>);
    final String groupId = j['g']! as String;
    final String name = (j['n'] as String?) ?? '';
    final String key = j['k']! as String;
    if (key.isEmpty || _engine.groupIds.contains(groupId)) return; // already in
    final List<GroupMember> roster = <GroupMember>[
      for (final Object? m in (j['m'] as List<Object?>? ?? const <Object?>[]))
        GroupMember.fromWire(groupId, (m! as Map).cast<String, Object?>()),
    ];

    final Channel channel = Channel(
      id: groupId,
      name: name,
      joinedAt: _nowMs(),
      isPrivate: true,
      groupKey: key,
    );
    await _channels.upsert(channel);
    _engine.groupIds.add(groupId);
    _channelList
      ..removeWhere((Channel c) => c.id == groupId)
      ..insert(0, channel);
    await _groupMembers.upsertAll(roster);
    _groupRosters[groupId] = roster;
    for (final GroupMember m in roster) {
      final PeerKeys? pk = AppKeys.parseBundle(m.pubBundle);
      if (pk != null) _peerKeys.putIfAbsent(m.appId, () => pk);
    }
    notifyListeners();
  }

  /// Decrypt + authenticate an encrypted 1:1 message. Returns the plaintext, a
  /// placeholder if we lack the sender's key, or null to drop (forged/corrupt).
  Future<String?> _openDirectMessage(Envelope m) async {
    final AppKeys? keys = _keys;
    final PeerKeys? peer = _peerKeys[m.fromId];
    if (keys == null || peer == null) return '🔒 Encrypted message';
    final bool ok = await AppKeys.verifyB64(
      _signedBytes(
          id: m.id, from: m.fromId, to: m.toId, ts: m.ts, body: m.body),
      m.sig,
      peer.sign,
    );
    if (!ok) return null;
    final List<int>? clear = await keys.open(peer.agree, m.body);
    return clear == null ? null : utf8.decode(clear);
  }

  /// Decrypt an encrypted group message with the group key, verifying the
  /// sender's signature when we know their key. Returns null to drop.
  Future<String?> _openGroupMessage(Envelope m) async {
    final Channel? group = channelById(m.toId);
    if (group == null || group.groupKey.isEmpty) return '🔒 Encrypted message';
    final PeerKeys? sender = _peerKeys[m.fromId];
    if (sender != null) {
      final bool ok = await AppKeys.verifyB64(
        _signedBytes(
            id: m.id, from: m.fromId, to: m.toId, ts: m.ts, body: m.body),
        m.sig,
        sender.sign,
      );
      if (!ok) return null; // forged by someone whose key we hold
    }
    final List<int>? clear = await AppKeys.openSym(group.groupKey, m.body);
    return clear == null ? null : utf8.decode(clear);
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
  Future<void> onHelloReceived(
    String appId,
    String displayName,
    String publicKeys,
  ) async {
    if (appId == identity.appId) return;
    await _contacts.upsert(
      appId: appId,
      name: displayName.isEmpty ? 'Unknown' : displayName,
      lastSeen: _nowMs(),
      pubBundle: publicKeys,
    );
    final PeerKeys? pk = AppKeys.parseBundle(publicKeys);
    if (pk != null) _peerKeys[appId] = pk;
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
        // The hello body carries our public-key bundle so peers can encrypt
        // to us. It is public material; sharing it is safe.
        body: _keys?.publicBundle ?? '',
        ts: _nowMs(),
        ttl: 0,
        name: identity.name,
      );

  Future<void> _refreshContacts() async {
    _contactList
      ..clear()
      ..addAll(await _contacts.all());
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static String _shortName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return 'Kabootar';
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

/// Session-only reassembly state for one incoming media transfer.
class _IncomingMedia {
  _IncomingMedia({
    required this.enc,
    required this.convId,
    required this.fromId,
    required this.total,
    required this.ext,
  });

  final bool enc;
  final String convId;
  final String fromId;
  final int total;
  final String ext;
}
