<div align="center">

# studchat

**Messaging that keeps working when the network does not.**

Messages hop phone to phone over Bluetooth and Wi-Fi and are delivered whenever
the recipient comes back in range. No servers, no accounts, no internet.

[![engine](https://img.shields.io/badge/mesh_engine-24_invariants_green-2ea44f)](tool/engine_check.dart)
[![Flutter](https://img.shields.io/badge/Flutter-3.22%2B-02569B?logo=flutter)](https://flutter.dev)
[![platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](docs/PLATFORM_SETUP.md)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

---

## What it is

studchat is a private 1:1 messenger built on a **delay-tolerant network (DTN)**.
Instead of routing through a server, your phone forms a peer-to-peer mesh with
other phones nearby. A message you send is flooded to everyone in range, carried
onward by each device it reaches, and delivered the moment a chain of carriers
connects you to the recipient - even if that is minutes later, after you have
both walked away.

It is the familiar personal-chat experience - a contact list, saved history,
sent / delivered receipts - but the transport underneath is a store-and-forward
mesh rather than the cloud.

### When it wins

Anywhere there is no signal but there are people around:

- Dead-zone buildings, basements, auditoriums, exam halls on airplane mode.
- Festivals, protests, stadiums, where cell networks jam.
- Travel and remote areas with no coverage; data run out; roaming with no plan.

The common thread: **proximity is available even when the internet is not.**

## The interesting part: the mesh engine

The heart of studchat is a framework-free routing engine implementing
**epidemic routing with end-to-end acknowledgements**. It has no dependency on
Flutter, the radio, or the database - which is why its entire behaviour is
pinned down by tests that run in plain Dart.

Every message is a tiny self-describing `Envelope` (`hello` / `msg` / `ack`),
and every node applies the same six rules to each one it receives:

| # | Rule | Why |
|---|------|-----|
| 1 | **De-dup** by envelope id | Idempotency. Stops loops and flood amplification. The single most important line in the protocol. |
| 2 | **Learn** from a `hello` | Builds the contact list from whoever comes into range. Link-local, never relayed. |
| 3 | **Deliver** if addressed to me | Persist, display, and emit an `ack`. |
| 4 | **Receipt** on an `ack` for me | Flip my sent message to *delivered*. |
| 5 | **Relay / carry** otherwise | Decrement TTL, cache, and re-flood. The message now rides this phone until it meets someone new. |
| 6 | **Cap** everything | TTL + max-age + max-cache-size bound storage, battery, and flood radius. Seeing an `ack` lets a carrier stop hauling the message it acknowledges. |

This is at-least-once delivery with idempotent de-dup and end-to-end receipts -
the same shape as a durable message queue, running across a swarm of phones
instead of a datacenter.

```
   Alice ──▶ (floods)         Relay R                     Bob (offline)
     │        envelope ──────▶ carries it ...                 ·
     │                         ... time passes, Alice leaves  ·
     │                         R meets Bob ─────────────────▶ delivers
     │                                                        emits ack
     ◀────────────────────────  ack carried back  ◀──────────────┘
   marks "delivered"
```

Read the deep-dive in **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

## Verify the routing without a phone

The engine is provable on a laptop. This harness stands up a simulated
multi-node network and asserts 24 routing invariants - direct delivery, de-dup,
multi-hop relay, store-and-forward across time, acks, TTL bounds, cache
eviction, and housekeeping - using only the Dart SDK:

```bash
dart run tool/engine_check.dart
```

```
── Store-and-forward across time (recipient offline, then returns)
  ✓ nobody delivered yet (C never in range)
  ✓ R is carrying the message for later
  ✓ C finally received it after coming back in range
  ✓ A eventually learns it was delivered
  ...
  24 passed, 0 failed
  all mesh-engine invariants hold ✓
```

The same behaviour is covered as idiomatic `flutter test` suites in
[`test/`](test/).

## Architecture at a glance

```
┌──────────────────────────────────────────────────────────┐
│  UI  (Flutter, Material 3)                                │
│  onboarding · chats · people · chat · mesh diagnostics    │
├──────────────────────────────────────────────────────────┤
│  ChatService   the seam: state, hello handshake, ticks    │
├───────────────┬───────────────────────┬──────────────────┤
│  MeshEngine   │  Data (SQLite)        │  Transport        │
│  DTN routing  │  messages · contacts  │  Nearby / Multi-  │
│  (pure Dart)  │  seen (dedup set)     │  peer P2P cluster │
└───────────────┴───────────────────────┴──────────────────┘
```

- **`lib/core/mesh`** - the engine, envelope, config, and ports. Zero framework
  imports.
- **`lib/data`** - `sqflite` persistence and the identity store; the `seen` set
  is persisted so a restart cannot re-flood the mesh.
- **`lib/transport`** - a `MeshTransport` interface with a
  `flutter_nearby_connections` implementation (Google Nearby on Android,
  MultipeerConnectivity on iOS).
- **`lib/services/chat_service.dart`** - the single source of truth the UI binds
  to; it *is* the engine's delegate and outbound port and the transport's
  listener.
- **`lib/ui`** - a polished Material 3 messenger, including a live **Mesh** tab
  that visualises routing decisions as they happen.

## Honest constraints

Designed in up front, so nothing surprises you:

- **Cross-platform wall.** One Flutter codebase runs on both, but a message
  cannot hop across the OS boundary: Android and iOS use different peer-to-peer
  radios. v1 meshes Android⇄Android and iOS⇄iOS.
- **Range and density.** Delivery depends on a chain of carriers existing
  between sender and recipient. Sparse crowds mean slow or no delivery. This is
  inherent to any mesh, not a bug.
- **Plaintext in v1.** Encryption is deferred (see the roadmap). Messages are
  not end-to-end encrypted yet.
- **Battery.** Continuous advertise + scan is not free; sane duty-cycling is a
  later milestone.

## Getting started

```bash
flutter create . --platforms=android,ios --org dev.studchat   # materialise the native shell
flutter pub get
flutter run                                                    # on a physical device
```

Full platform notes (permissions, minimum SDKs, why you need two real devices)
are in **[docs/PLATFORM_SETUP.md](docs/PLATFORM_SETUP.md)**.

## Roadmap

- [x] Onboarding, live peer discovery, 1:1 text chat
- [x] Store-and-forward with de-dup, TTL, and end-to-end acks
- [x] Persistent history and contacts; resume undelivered on restart
- [ ] End-to-end encryption (per-contact keys)
- [ ] Group rooms
- [ ] Media over Wi-Fi transport
- [ ] Battery duty-cycling
- [ ] Online bridge: any node with internet relays onward

## License

MIT - see [LICENSE](LICENSE).
