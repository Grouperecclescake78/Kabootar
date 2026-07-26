/// Plain-language legal text shown in-app and mirrored in the repo's
/// PRIVACY.md and TERMS.md. Written to be honest and human-readable.
abstract class Legal {
  static const String privacy =
      'Kabootar is built to keep your conversations yours.\n\n'
      '• No account, no phone number, no sign-up. A random device id is '
      'created on first launch and never leaves your phone.\n\n'
      '• No servers. There is no cloud and no company database. Your identity, '
      'contacts and chat history live only in local storage on your device.\n\n'
      '• How messages travel. Messages move directly between phones over '
      'Bluetooth and Wi-Fi. To reach someone out of range, a message may be '
      'carried and relayed by other nearby Kabootar users’ devices until it '
      'is delivered.\n\n'
      '• Encryption. Direct 1:1 chats and private groups are end-to-end '
      'encrypted (X25519 key agreement, AES-GCM, and Ed25519 signatures), so '
      'relays that carry them see only ciphertext. Your keys are generated on '
      'your device and never leave it, and each chat shows a safety code you '
      'can compare in person. Open channels are public broadcasts that anyone '
      'with the code can read, so they are not encrypted by design.\n\n'
      '• Permissions. Bluetooth, nearby-Wi-Fi and location permissions are '
      'used only to discover and connect to nearby devices. Kabootar does not '
      'collect, store, or transmit your location, and has no analytics, no '
      'ads, and no third-party trackers.\n\n'
      '• Your control. Uninstalling the app removes its local data from your '
      'device.\n\n'
      'One honest caveat: keys are long-lived, so Kabootar does not yet '
      'provide forward secrecy. For everyday conversations this is fine; for '
      'highly sensitive material, keep that limitation in mind.';

  static const String terms =
      'By using Kabootar you agree to the following.\n\n'
      '• As-is software. Kabootar is free, open-source software provided '
      '“as is”, without warranty of any kind, under the MIT License. The '
      'authors are not liable for any loss or damage arising from its use.\n\n'
      '• Best-effort delivery. Delivery depends on other devices being in '
      'range to carry your message. Kabootar does not guarantee that any '
      'message will be delivered, or delivered on time. Do not rely on it for '
      'emergency or safety-critical communication.\n\n'
      '• Encryption and privacy. Direct chats and private groups are '
      'end-to-end encrypted; open channels are public by design. Keys are '
      'long-lived, so there is no forward secrecy yet. Use your judgement '
      'before sending highly sensitive information.\n\n'
      '• Your content, your responsibility. You are responsible for what you '
      'send. Do not use Kabootar to send unlawful, harassing, or harmful '
      'content, or to infringe anyone’s rights.\n\n'
      '• Respect the law. Use Kabootar in accordance with the laws that apply '
      'to you.\n\n'
      'If you do not agree with these terms, please do not use the app.';
}
