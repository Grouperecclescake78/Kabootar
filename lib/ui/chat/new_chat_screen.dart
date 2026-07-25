import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../channels/channel_chat_screen.dart';
import '../widgets/avatar.dart';
import '../widgets/made_in_india.dart';
import 'chat_screen.dart';

/// The "New chat" screen, opened from the Chats FAB. Lets you start a note to
/// yourself, create/join a channel, or pick anyone the mesh has introduced you
/// to. Selecting an entry replaces this screen with the conversation, so Back
/// returns to the chat list.
class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _newChannel(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('New channel'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '#',
            hintText: 'e.g. campus, hostel-3, cricket',
          ),
          onSubmitted: (String v) => Navigator.pop(ctx, v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final Channel channel =
        await context.read<ChatService>().joinOrCreateChannel(name);
    if (context.mounted) {
      _open(context, ChannelChatScreen(channel: channel));
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('New chat'),
        bottom: const TricolorLine(),
      ),
      body: ListView(
        children: <Widget>[
          _ActionTile(
            icon: Icons.bookmark_outline,
            title: 'Message yourself',
            subtitle: 'Notes, links and reminders, saved on this device',
            onTap: () => _open(
              context,
              ChatScreen(peer: service.selfContact),
            ),
          ),
          _ActionTile(
            icon: Icons.campaign_outlined,
            title: 'New channel',
            subtitle: 'A broadcast room anyone nearby can join by name',
            onTap: () => _newChannel(context),
          ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              people.isEmpty
                  ? 'PEOPLE ON THE MESH'
                  : 'PEOPLE ON THE MESH · ${people.where((Contact c) => service.isOnline(c.appId)).length} nearby',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'No one yet. People appear here the moment they come into '
                'range with Studchat open.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            ...people.map(
              (Contact c) => ListTile(
                leading: Avatar(
                  initials: c.initials,
                  seed: c.appId,
                  online: service.isOnline(c.appId),
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  service.isOnline(c.appId) ? 'In range now' : 'Not in range',
                  style: const TextStyle(fontSize: 12.5),
                ),
                onTap: () => _open(context, ChatScreen(peer: c)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
    );
  }
}
