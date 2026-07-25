import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// This device's long-term key material and the operations built on it:
///
///   * **Ed25519** for signatures - proves a message really came from its
///     claimed sender and was not altered in flight by a relay.
///   * **X25519** for key agreement - two devices derive a shared secret from
///     their key pairs without ever sending it, and that secret encrypts the
///     message body (AES-GCM). Relays only ever see ciphertext.
///
/// Pure Dart (package:cryptography), so it adds no native code to the build.
///
/// Note on scope: this uses static key agreement (one long-term X25519 key per
/// device), so it is authenticated and confidential but not forward-secret - a
/// future ratchet could add that. Keys are trusted on first contact (TOFU); the
/// safety code lets two people verify out-of-band that nobody is in the middle.
class AppKeys {
  AppKeys._(this._signing, this._agreement, this.signPublic, this.agreePublic);

  final SimpleKeyPair _signing; // Ed25519
  final SimpleKeyPair _agreement; // X25519
  final SimplePublicKey signPublic;
  final SimplePublicKey agreePublic;

  static final Ed25519 _ed = Ed25519();
  static final X25519 _x = X25519();
  static final AesGcm _aead = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const List<int> _info = <int>[
    ...<int>[115, 116, 117, 100, 99, 104, 97, 116] // "studchat"
  ];

  /// Public keys to advertise in a hello, as "<ed>.<x>" (base64url). This is a
  /// device's public identity; sharing it is safe.
  String get publicBundle =>
      '${base64Url.encode(signPublic.bytes)}.${base64Url.encode(agreePublic.bytes)}';

  /// A short, human-comparable safety code for this device's identity. Two
  /// people reading the same code out loud confirms no man-in-the-middle.
  Future<String> safetyCode() => fingerprint(publicBundle);

  // --- Lifecycle -----------------------------------------------------------

  static Future<AppKeys> generate() async {
    final SimpleKeyPair signing = await _ed.newKeyPair();
    final SimpleKeyPair agreement = await _x.newKeyPair();
    return AppKeys._(
      signing,
      agreement,
      await signing.extractPublicKey(),
      await agreement.extractPublicKey(),
    );
  }

  /// The two private seeds, base64url "<ed>.<x>", for secure-ish local storage.
  Future<String> exportSeeds() async {
    final List<int> ed = await _signing.extractPrivateKeyBytes();
    final List<int> x = await _agreement.extractPrivateKeyBytes();
    return '${base64Url.encode(ed)}.${base64Url.encode(x)}';
  }

  static Future<AppKeys> fromSeeds(String stored) async {
    final List<String> parts = stored.split('.');
    final SimpleKeyPair signing =
        await _ed.newKeyPairFromSeed(base64Url.decode(parts[0]));
    final SimpleKeyPair agreement =
        await _x.newKeyPairFromSeed(base64Url.decode(parts[1]));
    return AppKeys._(
      signing,
      agreement,
      await signing.extractPublicKey(),
      await agreement.extractPublicKey(),
    );
  }

  // --- Peer key bundles ----------------------------------------------------

  /// Parse a peer's advertised "<ed>.<x>" bundle into its two public keys, or
  /// null if it is malformed.
  static PeerKeys? parseBundle(String? bundle) {
    if (bundle == null) return null;
    final List<String> parts = bundle.split('.');
    if (parts.length != 2) return null;
    try {
      return PeerKeys(
        sign: SimplePublicKey(base64Url.decode(parts[0]),
            type: KeyPairType.ed25519),
        agree: SimplePublicKey(base64Url.decode(parts[1]),
            type: KeyPairType.x25519),
      );
    } catch (_) {
      return null;
    }
  }

  /// A short hex safety code derived from a public bundle (first bytes of its
  /// SHA-256), grouped for readability.
  static Future<String> fingerprint(String bundle) async {
    final Hash h = await Sha256().hash(utf8.encode(bundle));
    final String hex = h.bytes
        .take(8)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 4)} ${hex.substring(4, 8)} '
            '${hex.substring(8, 12)} ${hex.substring(12, 16)}'
        .toUpperCase();
  }

  // --- Signing -------------------------------------------------------------

  /// Sign [message]; returns the base64url signature.
  Future<String> signB64(List<int> message) async {
    final Signature sig = await _ed.sign(message, keyPair: _signing);
    return base64Url.encode(sig.bytes);
  }

  /// Verify a base64url [signatureB64] over [message] against [signer]'s key.
  static Future<bool> verifyB64(
    List<int> message,
    String signatureB64,
    SimplePublicKey signer,
  ) async {
    try {
      return await _ed.verify(
        message,
        signature: Signature(base64Url.decode(signatureB64), publicKey: signer),
      );
    } catch (_) {
      return false;
    }
  }

  // --- Encryption ----------------------------------------------------------

  /// Encrypt [plaintext] to a peer's X25519 public key. Returns a base64url
  /// blob (nonce + ciphertext + MAC) safe to put on the wire.
  Future<String> seal(SimplePublicKey peerAgree, List<int> plaintext) async {
    final SecretKey key = await _deriveKey(peerAgree);
    final SecretBox box = await _aead.encrypt(plaintext, secretKey: key);
    return base64Url.encode(box.concatenation());
  }

  /// Decrypt a base64url blob from a peer, or null if it fails to authenticate
  /// (tampered, wrong key, or corrupt).
  Future<List<int>?> open(SimplePublicKey peerAgree, String blobB64) async {
    try {
      final SecretKey key = await _deriveKey(peerAgree);
      final SecretBox box = SecretBox.fromConcatenation(
        base64Url.decode(blobB64),
        nonceLength: _aead.nonceLength,
        macLength: _aead.macAlgorithm.macLength,
      );
      return await _aead.decrypt(box, secretKey: key);
    } catch (_) {
      return null;
    }
  }

  Future<SecretKey> _deriveKey(SimplePublicKey peerAgree) async {
    final SecretKey shared = await _x.sharedSecretKey(
      keyPair: _agreement,
      remotePublicKey: peerAgree,
    );
    return _hkdf.deriveKey(secretKey: shared, info: _info);
  }
}

/// A peer's two public keys, learned from their hello.
class PeerKeys {
  const PeerKeys({required this.sign, required this.agree});
  final SimplePublicKey sign; // Ed25519
  final SimplePublicKey agree; // X25519
}
