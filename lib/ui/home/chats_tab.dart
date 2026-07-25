import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';
import 'archived_chats_screen.dart';
import 'conversation_tile.dart';

/// The conversation list - contacts you have exchanged messages with, newest
/// activity first, with a one-line preview and unread-agnostic timestamp.
/// Long-press a row to archive, hide, clear, block or delete it.
class ChatsTab extends StatelessWidget {
  const ChatsTab({required this.onOpenChat, super.key});

  final void Function(Contact) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();

    final List<Contact> withChats = service.conversationContacts();
    final int archived = service.archivedCount;

    if (withChats.isEmpty && archived == 0) {
      return const Column(
        children: <Widget>[
          DidYouKnowStrip(),
          Expanded(
            child: EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'When someone comes into range, they appear under People. '
                  'Start a chat and it will show up here.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        const DidYouKnowStrip(),
        if (archived > 0) _ArchivedBar(count: archived),
        Expanded(
          child: ListView.separated(
            itemCount: withChats.length,
            separatorBuilder: (_, __) => const Divider(indent: 80),
            itemBuilder: (BuildContext context, int i) =>
                ConversationTile(contact: withChats[i], onOpen: onOpenChat),
          ),
        ),
      ],
    );
  }
}

class _ArchivedBar extends StatelessWidget {
  const _ArchivedBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final Color muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Column(
      children: <Widget>[
        ListTile(
          leading: Icon(Icons.archive_outlined, color: muted),
          title: Text(
            'Archived',
            style: TextStyle(fontWeight: FontWeight.w600, color: muted),
          ),
          trailing: Text(
            '$count',
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ArchivedChatsScreen(),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
