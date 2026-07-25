import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/message.dart';
import '../widgets/status_ticks.dart';

/// A WhatsApp-style "Message info" sheet: when a message was sent, delivered,
/// and read (for outgoing), or received (for incoming).
Future<void> showMessageInfo(BuildContext context, Message message) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _MessageInfoSheet(message: message),
  );
}

class _MessageInfoSheet extends StatelessWidget {
  const _MessageInfoSheet({required this.message});

  final Message message;

  String _fmt(int? ms) => ms == null
      ? 'Not yet'
      : DateFormat('d MMM, h:mm a').format(
          DateTime.fromMillisecondsSinceEpoch(ms),
        );

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Message info',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.body,
                style: const TextStyle(fontSize: 14.5, height: 1.3),
              ),
            ),
            const SizedBox(height: 16),
            if (message.isOutgoing) ...<Widget>[
              _row(
                context,
                icon: Icons.done_all,
                iconColor: message.status == MessageStatus.read
                    ? const Color(0xFF38BDF8)
                    : scheme.onSurface.withValues(alpha: 0.5),
                label: 'Read',
                value: _fmt(message.readAt),
              ),
              _row(
                context,
                icon: Icons.done_all,
                iconColor: scheme.onSurface.withValues(alpha: 0.5),
                label: 'Delivered',
                value: _fmt(message.deliveredAt),
              ),
              _row(
                context,
                icon: Icons.done,
                iconColor: scheme.onSurface.withValues(alpha: 0.5),
                label: 'Sent',
                value: _fmt(message.timestamp),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  StatusTicks(
                    message.status,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${message.status.label}',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ] else
              _row(
                context,
                icon: Icons.call_received,
                iconColor: scheme.primary,
                label: 'Received',
                value: _fmt(message.timestamp),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
