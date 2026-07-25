import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/contact.dart';
import '../../core/models/group_member.dart';
import '../../services/chat_service.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/made_in_india.dart';

/// The roster of a private group, with a way to invite more contacts. Anyone
/// already a member can add people; invites are sent encrypted to each contact.
class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({required this.group, super.key});

  final Channel group;

  Future<void> _invite(BuildContext context) async {
    final ChatService service = context.read<ChatService>();
    final List<Contact> candidates = service.invitableContacts(group.id);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No one to invite yet. You can invite contacts whose keys you '
            'have (met them once in range).',
          ),
        ),
      );
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Invite to group',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (BuildContext _, int i) {
                  final Contact c = candidates[i];
                  return ListTile(
                    leading: Avatar(initials: c.initials, seed: c.appId),
                    title: Text(c.name),
                    trailing: const Icon(Icons.person_add_alt_1_outlined),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final bool ok = await service.inviteToGroup(group.id, c);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Invited ${c.name}'
                                : 'Could not invite ${c.name}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final List<GroupMember> members = service.groupMembers(group.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        bottom: const TricolorLine(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _invite(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite'),
      ),
      body: members.isEmpty
          ? const EmptyState(
              icon: Icons.group_outlined,
              title: 'Just you',
              message: 'Invite contacts to this private group. Only members '
                  'can read what is posted here.',
            )
          : ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(indent: 72),
              itemBuilder: (BuildContext context, int i) {
                final GroupMember m = members[i];
                final bool isSelf = service.isSelf(m.appId);
                return ListTile(
                  leading: Avatar(initials: m.initials, seed: m.appId),
                  title: Text(isSelf ? '${m.name} (You)' : m.name),
                  subtitle: Text(
                    m.pubBundle.isEmpty ? 'No key yet' : 'Encrypted member',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
