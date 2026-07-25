import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/made_in_india.dart';
import 'conversation_tile.dart';

/// The archived conversations, tucked away from the main Chats list. Long-press
/// a row to unarchive or delete it; a new message also brings a chat back on
/// its own.
class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final List<Contact> archived = service.archivedConversations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived'),
        bottom: const TricolorLine(),
      ),
      body: archived.isEmpty
          ? const EmptyState(
              icon: Icons.archive_outlined,
              title: 'No archived chats',
              message:
                  'Archived conversations are tucked away here. Long-press '
                  'a chat in the list to archive it.',
            )
          : ListView.separated(
              itemCount: archived.length,
              separatorBuilder: (_, __) => const Divider(indent: 80),
              itemBuilder: (BuildContext context, int i) => ConversationTile(
                contact: archived[i],
                onOpen: (Contact c) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(peer: c),
                  ),
                ),
              ),
            ),
    );
  }
}
