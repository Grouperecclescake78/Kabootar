# Security Policy

## Reporting a vulnerability

Please report security issues **privately**, not as public issues:

- Open a [GitHub security advisory](https://github.com/royalpinto007/studchat/security/advisories/new), or
- email the maintainer.

You will get an acknowledgement, and a fix or mitigation plan. Please give a
reasonable window to address the issue before any public disclosure.

## Scope and current guarantees

Studchat is an offline mesh messenger. Be aware of what v1 does and does **not**
guarantee:

| Property | Status in v1 |
| --- | --- |
| No servers / no cloud account | ✅ Yes, by design |
| Data stays on device | ✅ Identity, contacts, and history are local (SQLite / prefs) |
| End-to-end encryption | ❌ **Not yet.** Messages are plaintext on the wire |
| Sender authenticity | ❌ App ids are self-asserted; no signing yet |
| Metadata privacy | ⚠️ Nearby peers can observe that traffic is flowing |

Because messages are **plaintext in v1**, treat the current release as suitable
for casual and hobby use, not for sensitive communication. End-to-end
encryption (per-contact keys) and message signing are on the
[roadmap](README.md#roadmap) and are the top security priorities.

## Supported versions

The latest `main` and the most recent tagged release receive fixes.
