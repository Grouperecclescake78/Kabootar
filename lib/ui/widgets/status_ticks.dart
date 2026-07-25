import 'package:flutter/material.dart';

import '../../core/models/message.dart';
import '../../theme/app_theme.dart';

/// The little delivery indicator on an outgoing message - the familiar
/// clock / single-tick / double-tick / blue-double-tick language, mapped to
/// states studchat can actually prove:
///   sending   → clock (queued, no peer yet)
///   sent      → single tick (handed to the mesh)
///   delivered → double blue tick (end-to-end ack came back)
///   failed    → error glyph
class StatusTicks extends StatelessWidget {
  const StatusTicks(this.status, {this.color, super.key});

  final MessageStatus status;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color base =
        color ?? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7);
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule, size: 14, color: base);
      case MessageStatus.sent:
        return Icon(Icons.done, size: 15, color: base);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 15, color: AppColors.delivered);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red.shade300);
    }
  }
}

extension MessageStatusLabel on MessageStatus {
  String get label {
    switch (this) {
      case MessageStatus.sending:
        return 'Queued';
      case MessageStatus.sent:
        return 'Sent to mesh';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.failed:
        return 'Failed';
    }
  }
}
