import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../format.dart';
import '../widgets/avatar.dart';
import '../widgets/status_ticks.dart';
import 'conversation_actions.dart';

/// One row in a conversation list: avatar, name, last-message preview, and the
/// time. Tap opens the chat; long-press opens the management sheet (archive,
/// hide, clear, block, delete). Shared by the Chats tab and the Archived
/// screen.
class ConversationTile extends StatelessWidget {
  const ConversationTile(
      {required this.contact, required this.onOpen, super.key});

  final Contact contact;
  final void Function(Contact) onOpen;

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final Message? last = service.latestWith(contact.appId);
    if (last == null) return const SizedBox.shrink();
    final bool self = service.isSelf(contact.appId);
    final bool blocked = service.isBlocked(contact.appId);
    final bool unread = service.isUnread(contact.appId);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color muted = scheme.onSurface.withValues(alpha: 0.6);

    return ListTile(
      onTap: () => onOpen(contact),
      onLongPress: () => showConversationActions(context, contact),
      leading: Avatar(
        initials: contact.initials,
        seed: contact.appId,
        online: !self && service.isOnline(contact.appId),
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              self ? '${contact.name} (You)' : contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (blocked) ...<Widget>[
            const SizedBox(width: 6),
            Icon(Icons.block, size: 14, color: muted),
          ],
        ],
      ),
      subtitle: Row(
        children: <Widget>[
          if (last.isOutgoing) ...<Widget>[
            StatusTicks(
              last.status,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              last.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread ? scheme.onSurface : muted,
                fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            relativeTime(last.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: unread
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (unread) ...<Widget>[
            const SizedBox(height: 5),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
