# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-07-25

The first release: a working offline mesh messenger with a fully-verified
delay-tolerant routing engine.

### Added

- **Mesh engine** - framework-free store-and-forward core implementing epidemic
  routing with end-to-end acknowledgements: idempotent de-dup, deliver, relay
  and carry, TTL / max-age / max-cache-size bounds, and ack-driven carry
  clearing.
- **Store-and-forward across time** - flush-on-connect delivers messages to a
  recipient who was offline when they were sent.
- **Persistence** - SQLite for messages, contacts, and the de-dup set (persisted
  so a restart cannot re-flood); undelivered messages resume on launch.
- **Transport** - `flutter_nearby_connections` (Google Nearby on Android,
  MultipeerConnectivity on iOS) behind a swappable `MeshTransport` interface.
- **UI** - Material 3 messenger: onboarding, Chats / People / Mesh tabs, 1:1
  chat with delivery ticks, offline carry banner, and a live mesh activity feed.
- **Verification** - a dependency-free harness asserting 24 routing invariants,
  plus `flutter_test` suites for the engine and envelope.

### Known limitations

- No cross-platform mesh (Android⇄iOS) - different peer-to-peer radios.
- Messages are plaintext; end-to-end encryption is planned.
- No battery duty-cycling yet.
