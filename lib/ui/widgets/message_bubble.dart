import 'package:flutter/material.dart';

import '../../core/models/message.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import 'status_ticks.dart';

/// One chat bubble. Outgoing bubbles are brand-coloured and right-aligned with
/// a delivery tick; incoming are neutral and left-aligned. In a channel, an
/// incoming bubble is labelled with [senderName].
class MessageBubble extends StatelessWidget {
  const MessageBubble(this.message, {this.senderName, super.key});

  final Message message;

  /// Name of the sender, shown above an incoming channel bubble. Null in 1:1.
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    final bool mine = message.isOutgoing;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bubbleColor = mine
        ? scheme.primary
        : (isDark ? AppColors.bubbleInDark : AppColors.bubbleInLight);
    final Color textColor = mine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          boxShadow: mine
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _nameColor(senderName!),
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(color: textColor, fontSize: 15.5, height: 1.32),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  clockTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
                if (mine) ...<Widget>[
                  const SizedBox(width: 4),
                  StatusTicks(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const List<Color> _namePalette = <Color>[
    Color(0xFF0EA5A4),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF059669),
  ];

  Color _nameColor(String name) {
    final int h = name.codeUnits.fold<int>(0, (int a, int c) => a + c);
    return _namePalette[h % _namePalette.length];
  }
}
