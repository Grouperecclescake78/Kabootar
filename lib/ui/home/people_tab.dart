import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../format.dart';
import '../widgets/avatar.dart';

/// Everyone the mesh has ever introduced us to, in-range peers first. The list
/// is discovered over the radio, never typed in - so "add people" here explains
/// how discovery works and lets you invite others.
class PeopleTab extends StatelessWidget {
  const PeopleTab({required this.onOpenChat, super.key});

  final void Function(Contact) onOpenChat;

  void _addPeople(BuildContext context) {
    final String appId = context.read<ChatService>().identity.appId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        // SafeArea(bottom) keeps the last button clear of the system
        // navigation bar; without it the fixed padding collides with it.
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Add people',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'There is no server and no friend list to sync. People appear '
                  'here automatically the moment they open Kabootar near you, so '
                  'the way to "add" someone is simply to be nearby with Bluetooth '
                  'and Wi-Fi on.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      const ClipboardData(
                        text:
                            "Let's chat on Kabootar - it works offline, phone to "
                            'phone, no internet or SIM needed. Get it and open it '
                            'near me.',
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite message copied')),
                    );
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Copy an invite message'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: appId));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Your mesh address copied')),
                    );
                  },
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Copy my mesh address'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

    final int online =
        people.where((Contact c) => service.isOnline(c.appId)).length;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  people.isEmpty
                      ? 'Scanning for people nearby…'
                      : online > 0
                          ? '$online in range now'
                          : '${people.length} met so far',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: online > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addPeople(context),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: people.isEmpty
              ? _Empty(onAdd: () => _addPeople(context))
              : ListView.separated(
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

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore_outlined,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Looking for people',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kabootar is scanning for nearby phones over Bluetooth and Wi-Fi. '
              'Anyone running Kabootar within range will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Invite people'),
            ),
          ],
        ),
      ),
    );
  }
}
