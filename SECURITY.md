# Security Policy

## Reporting a vulnerability

Please report security issues **privately**, not as public issues:

- Open a [GitHub security advisory](https://github.com/royalpinto007/kabootar/security/advisories/new), or
- email the maintainer.

You will get an acknowledgement, and a fix or mitigation plan. Please give a
reasonable window to address the issue before any public disclosure.

## Scope and current guarantees

Kabootar is an offline mesh messenger. Be aware of what v1 does and does **not**
guarantee:

| Property | Status in v1 |
| --- | --- |
| No servers / no cloud account | ✅ Yes, by design |
| Data stays on device | ✅ Identity, contacts, and history are local (SQLite / prefs) |
| End-to-end encryption | ✅ 1:1 chats and private groups (X25519 + AES-GCM). Open channels are public by design |
| Sender authenticity | ✅ Messages are Ed25519-signed; a per-chat safety code lets you verify keys in person |
| Forward secrecy | ❌ **Not yet.** Keys are long-lived, so a future ratchet is planned |
| Metadata privacy | ⚠️ Nearby peers can observe that traffic is flowing |

Direct chats and private groups are end-to-end encrypted and signed; keys are
generated on the device and never leave it. Open channels are public broadcasts
by design. The main remaining caveat is **no forward secrecy yet** (static
keys), so for highly sensitive communication keep that limitation in mind. A
message ratchet is the top security item on the [roadmap](README.md#-roadmap).

## Supported versions

The latest `main` and the most recent tagged release receive fixes.
