import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/made_in_india.dart';
import 'conversation_tile.dart';

/// Conversations the user has hidden. Reached from the profile sheet so a
/// hidden chat can always be found again. Long-press a row to unhide or delete
/// it; a new message from that person also brings it back on its own.
class HiddenChatsScreen extends StatelessWidget {
  const HiddenChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final List<Contact> hidden = service.hiddenConversations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidden chats'),
        bottom: const TricolorLine(),
      ),
      body: hidden.isEmpty
          ? const EmptyState(
              icon: Icons.visibility_off_outlined,
              title: 'No hidden chats',
              message: 'Hidden conversations are kept off your Chats list and '
                  'live here. Long-press a chat and choose Hide to tuck it '
                  'away; long-press it here to unhide it.',
            )
          : ListView.separated(
              itemCount: hidden.length,
              separatorBuilder: (_, __) => const Divider(indent: 80),
              itemBuilder: (BuildContext context, int i) => ConversationTile(
                contact: hidden[i],
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
