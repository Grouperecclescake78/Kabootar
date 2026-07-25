import 'dart:convert';
import 'dart:typed_data';

import '../mesh/envelope.dart';
import 'app_keys.dart';

/// The per-message crypto that sits on top of [AppKeys]: building outgoing
/// (sealed + signed, or plaintext) envelopes and opening incoming ones, for
/// both 1:1 chats (pairwise keys) and private groups (a shared symmetric key).
///
/// Pulled out of ChatService so the security-critical logic has one home and
/// its own tests. It stays stateless apart from injected lookups: which key we
/// hold for a peer, which key a group uses, and whether an id is a group.
class MessageCipher {
  MessageCipher({
    required AppKeys? keys,
    required this.myId,
    required this.ttl,
    required this.peerKeyOf,
    required this.groupKeyOf,
    required this.isGroup,
  }) : _keys = keys;

  final AppKeys? _keys;
  final String myId;
  final int ttl;

  /// A peer's public keys, or null if we have not learned them.
  final PeerKeys? Function(String appId) peerKeyOf;

  /// A private group's symmetric key, or null (open channel / unknown).
  final String? Function(String convId) groupKeyOf;

  /// Whether an id addresses a group (channel / private group) vs a 1:1 peer.
  final bool Function(String id) isGroup;

  /// Canonical bytes a signature covers: the immutable routing fields plus the
  /// (cipher)text. TTL is excluded because relays change it.
  static List<int> signedBytes({
    required String id,
    required String from,
    required String to,
    required int ts,
    required String body,
  }) =>
      utf8.encode('$id|$from|$to|$ts|$body');

  /// Build a 1:1 outgoing message envelope: sealed to the peer and signed when
  /// we hold their keys, otherwise plaintext, exactly as before encryption.
  Future<Envelope> buildOutgoing({
    required String id,
    required String toId,
    required String plaintext,
    required int ts,
  }) async {
    final AppKeys? keys = _keys;
    final PeerKeys? peer = peerKeyOf(toId);
    final bool encryptable =
        keys != null && peer != null && toId != myId && !isGroup(toId);
    if (encryptable) {
      final String blob = await keys.seal(peer.agree, utf8.encode(plaintext));
      final String sig = await keys.signB64(
        signedBytes(id: id, from: myId, to: toId, ts: ts, body: blob),
      );
      return Envelope(
        id: id,
        kind: EnvelopeKind.msg,
        fromId: myId,
        toId: toId,
        body: blob,
        ts: ts,
        ttl: ttl,
        enc: true,
        sig: sig,
      );
    }
    return Envelope(
      id: id,
      kind: EnvelopeKind.msg,
      fromId: myId,
      toId: toId,
      body: plaintext,
      ts: ts,
      ttl: ttl,
    );
  }

  /// Encrypt bytes for a conversation (group key, then pairwise, then
  /// plaintext). Returns the base64 payload and whether it was encrypted.
  Future<(String, bool)> encryptFor(String convId, List<int> bytes) async {
    final String? groupKey = groupKeyOf(convId);
    if (groupKey != null && groupKey.isNotEmpty) {
      return (await AppKeys.sealSym(groupKey, bytes), true);
    }
    final PeerKeys? peer = peerKeyOf(convId);
    if (_keys != null && peer != null && !isGroup(convId)) {
      return (await _keys.seal(peer.agree, bytes), true);
    }
    return (base64Url.encode(bytes), false);
  }

  /// Decrypt a media payload using the transfer's recorded mode.
  Future<Uint8List?> decryptPayload({
    required bool enc,
    required String convId,
    required String fromId,
    required String b64,
  }) async {
    if (b64.isEmpty) return null;
    if (!enc) {
      try {
        return Uint8List.fromList(base64Url.decode(b64));
      } catch (_) {
        return null;
      }
    }
    final String? groupKey = groupKeyOf(convId);
    if (groupKey != null && groupKey.isNotEmpty) {
      final List<int>? c = await AppKeys.openSym(groupKey, b64);
      return c == null ? null : Uint8List.fromList(c);
    }
    final PeerKeys? peer = peerKeyOf(fromId);
    if (_keys != null && peer != null) {
      final List<int>? c = await _keys.open(peer.agree, b64);
      return c == null ? null : Uint8List.fromList(c);
    }
    return null;
  }

  /// Decrypt + authenticate a 1:1 message. Returns plaintext, a placeholder if
  /// we lack the sender's key, or null to drop (forged / undecipherable).
  Future<String?> openDirectMessage(Envelope m) async {
    final AppKeys? keys = _keys;
    final PeerKeys? peer = peerKeyOf(m.fromId);
    if (keys == null || peer == null) return '🔒 Encrypted message';
    final bool ok = await AppKeys.verifyB64(
      signedBytes(id: m.id, from: m.fromId, to: m.toId, ts: m.ts, body: m.body),
      m.sig,
      peer.sign,
    );
    if (!ok) return null;
    final List<int>? clear = await keys.open(peer.agree, m.body);
    return clear == null ? null : utf8.decode(clear);
  }

  /// Decrypt a group message with its [groupKey], verifying the sender's
  /// signature when we know their key. Returns null to drop.
  Future<String?> openGroupMessage(Envelope m, String? groupKey) async {
    if (groupKey == null || groupKey.isEmpty) return '🔒 Encrypted message';
    final PeerKeys? sender = peerKeyOf(m.fromId);
    if (sender != null) {
      final bool ok = await AppKeys.verifyB64(
        signedBytes(
            id: m.id, from: m.fromId, to: m.toId, ts: m.ts, body: m.body),
        m.sig,
        sender.sign,
      );
      if (!ok) return null;
    }
    final List<int>? clear = await AppKeys.openSym(groupKey, m.body);
    return clear == null ? null : utf8.decode(clear);
  }
}
