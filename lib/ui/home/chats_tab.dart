import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../format.dart';
import '../widgets/avatar.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_ticks.dart';

/// The conversation list - contacts you have exchanged messages with, newest
/// activity first, with a one-line preview and unread-agnostic timestamp.
class ChatsTab extends StatelessWidget {
  const ChatsTab({required this.onOpenChat, super.key});

  final void Function(Contact) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();

    final List<Contact> withChats = <Contact>[
      // The "Message yourself" conversation shows up once it has any notes.
      if (service.latestWith(service.identity.appId) != null)
        service.selfContact,
      ...service.contacts.where(
        (Contact c) =>
            !service.isSelf(c.appId) && service.latestWith(c.appId) != null,
      ),
    ]..sort(
        (Contact a, Contact b) => service
            .latestWith(b.appId)!
            .timestamp
            .compareTo(service.latestWith(a.appId)!.timestamp),
      );

    if (withChats.isEmpty) {
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
        Expanded(
          child: ListView.separated(
            itemCount: withChats.length,
            separatorBuilder: (_, __) => const Divider(indent: 80),
            itemBuilder: (BuildContext context, int i) {
              final Contact c = withChats[i];
              final Message last = service.latestWith(c.appId)!;
              final bool self = service.isSelf(c.appId);
              return ListTile(
                onTap: () => onOpenChat(c),
                leading: self
                    ? CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(
                          Icons.bookmark_outline,
                          color: Colors.white,
                        ),
                      )
                    : Avatar(
                        initials: c.initials,
                        seed: c.appId,
                        online: service.isOnline(c.appId),
                      ),
                title: Text(
                  self ? '${c.name} (You)' : c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Row(
                  children: <Widget>[
                    if (last.isOutgoing) ...<Widget>[
                      StatusTicks(
                        last.status,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        last.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  relativeTime(last.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
