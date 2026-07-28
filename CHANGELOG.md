# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-07-25

The first release: a working offline mesh messenger with a fully-verified
delay-tolerant routing engine, end-to-end encryption, groups, and media.

### Added

- **Mesh engine** - framework-free store-and-forward core implementing epidemic
  routing with end-to-end acknowledgements: idempotent de-dup, deliver, relay
  and carry, TTL / max-age / max-cache-size bounds, and ack-driven carry
  clearing.
- **Store-and-forward across time** - flush-on-connect delivers messages to a
  recipient who was offline when they were sent.
- **End-to-end encryption** - 1:1 chats and private groups are sealed with
  X25519 key agreement, AES-GCM, and Ed25519 signatures. Public keys are learned
  from `hello` (trust-on-first-use), and each chat shows a safety code.
- **Private groups and channels** - invite-only groups encrypted with a shared
  key distributed via encrypted invites, plus open broadcast channels joined by
  a short code.
- **Media** - image sharing (compressed and thumbnailed) and arbitrary file
  sharing (up to 8 MB), sealed then chunked over the same carry path.
- **Chat management** - archive, hide, block, clear, delete, delete-for-everyone,
  mark-as-unread, multi-select, plus read receipts.
- **Notifications and theming** - local notifications on incoming messages, and
  light / dark / system themes.
- **Persistence** - SQLite (schema v8) for messages, contacts, keys, channels,
  group rosters, conversation flags, and the de-dup set; undelivered messages
  resume on launch.
- **Transport** - `flutter_nearby_connections` (Google Nearby on Android,
  MultipeerConnectivity on iOS) behind a swappable `MeshTransport` interface.
- **UI** - Material 3 messenger: onboarding, Chats / People / Channels / Mesh
  tabs, delivery ticks, offline carry banner, and a live mesh activity feed.
- **Verification** - a dependency-free harness asserting 32 routing invariants,
  plus `flutter_test` suites for the engine, envelope, crypto, and media codec.

### Known limitations

- No cross-platform mesh (Android⇄iOS) - different peer-to-peer radios.
- No forward secrecy yet - encryption uses long-lived static keys.
- Open channels are public by design (not encrypted).
- No battery duty-cycling yet.
