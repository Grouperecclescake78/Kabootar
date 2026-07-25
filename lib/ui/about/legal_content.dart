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
      'is delivered. Relays cannot read a message that is not for them, but '
      'in this version messages are NOT end-to-end encrypted, so treat them '
      'as not fully private from a determined nearby party.\n\n'
      '• Permissions. Bluetooth, nearby-Wi-Fi and location permissions are '
      'used only to discover and connect to nearby devices. Kabootar does not '
      'collect, store, or transmit your location, and has no analytics, no '
      'ads, and no third-party trackers.\n\n'
      '• Your control. Uninstalling the app removes its local data from your '
      'device.\n\n'
      'End-to-end encryption is the top item on the roadmap. Until then, '
      'please do not use Kabootar for sensitive information.';

  static const String terms =
      'By using Kabootar you agree to the following.\n\n'
      '• As-is software. Kabootar is free, open-source software provided '
      '“as is”, without warranty of any kind, under the MIT License. The '
      'authors are not liable for any loss or damage arising from its use.\n\n'
      '• Best-effort delivery. Delivery depends on other devices being in '
      'range to carry your message. Kabootar does not guarantee that any '
      'message will be delivered, or delivered on time. Do not rely on it for '
      'emergency or safety-critical communication.\n\n'
      '• Not encrypted in this version. Do not send passwords, financial '
      'details, or other sensitive information.\n\n'
      '• Your content, your responsibility. You are responsible for what you '
      'send. Do not use Kabootar to send unlawful, harassing, or harmful '
      'content, or to infringe anyone’s rights.\n\n'
      '• Respect the law. Use Kabootar in accordance with the laws that apply '
      'to you.\n\n'
      'If you do not agree with these terms, please do not use the app.';
}
