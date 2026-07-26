# Privacy Policy

_Last updated: 2026-07-26_

Kabootar is built to keep your conversations yours. In plain language:

- **No account, no phone number, no sign-up.** A random device id is created on
  first launch and never leaves your phone.
- **No servers.** There is no cloud and no company database. Your identity,
  contacts, and chat history live only in local storage on your device.
- **How messages travel.** Messages move directly between phones over Bluetooth
  and Wi-Fi. To reach someone out of range, a message may be carried and relayed
  by other nearby Kabootar users' devices until it is delivered.
- **Encryption.** Direct 1:1 chats and private groups are **end-to-end
  encrypted** (X25519 key agreement, AES-GCM, and Ed25519 signatures), so relays
  that carry them see only ciphertext. Your keys are generated on your device and
  never leave it, and each chat shows a safety code you can compare in person.
  Open channels are public broadcasts that anyone with the code can read, so they
  are not encrypted by design.
- **Permissions.** Bluetooth, nearby-Wi-Fi, and location permissions are used
  **only** to discover and connect to nearby devices. Kabootar does **not**
  collect, store, or transmit your location, and has **no analytics, no ads, and
  no third-party trackers**.
- **Your control.** Uninstalling the app removes its local data from your device.

One honest caveat: keys are long-lived, so Kabootar does not yet provide forward
secrecy. For everyday conversations this is fine; for highly sensitive material,
keep that limitation in mind.

Questions? Open an issue or a private
[security advisory](https://github.com/royalpinto007/kabootar/security/advisories/new).
