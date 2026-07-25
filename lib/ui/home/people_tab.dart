import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../format.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';

/// Everyone the mesh has ever introduced us to, in-range peers first. This is
/// where a conversation begins - the list is discovered, never typed in.
class PeopleTab extends StatelessWidget {
  const PeopleTab({required this.onOpenChat, super.key});

  final void Function(Contact) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final List<Contact> people = service.contacts.toList()
      ..sort((Contact a, Contact b) {
        final bool ao = service.isOnline(a.appId);
        final bool bo = service.isOnline(b.appId);
        if (ao != bo) return ao ? -1 : 1;
        return b.lastSeen.compareTo(a.lastSeen);
      });

    if (people.isEmpty) {
      return const EmptyState(
        icon: Icons.travel_explore_outlined,
        title: 'Looking for people',
        message:
            'studchat is scanning for nearby phones over Bluetooth and Wi-Fi. '
            'Anyone running studchat within range will appear here.',
      );
    }

    final int online = people
        .where((Contact c) => service.isOnline(c.appId))
        .length;

    return Column(
      children: <Widget>[
        if (online > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$online in range now',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: people.length,
            separatorBuilder: (_, __) => const Divider(indent: 80),
            itemBuilder: (BuildContext context, int i) {
              final Contact c = people[i];
              final bool isOnline = service.isOnline(c.appId);
              return ListTile(
                onTap: () => onOpenChat(c),
                leading: Avatar(
                  initials: c.initials,
                  seed: c.appId,
                  online: isOnline,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isOnline
                      ? 'In range now'
                      : 'Last seen ${relativeTime(c.lastSeen)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOnline
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
              );
            },
          ),
        ),
      ],
    );
  }
}
