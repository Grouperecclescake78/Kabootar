import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../format.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';

/// Lists the broadcast channels you have joined, and lets you join or create
/// one by name. A channel is a room anyone nearby can enter by its name.
class ChannelsTab extends StatelessWidget {
  const ChannelsTab({required this.onOpenChannel, super.key});

  final void Function(Channel) onOpenChannel;

  Future<void> _showJoin(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Join or create a channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                prefixText: '#',
                hintText: 'e.g. campus, hostel-3, cricket',
              ),
              onSubmitted: (String v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 10),
            Text(
              'Anyone nearby who joins the same name lands in the same channel. '
              'No server, no invite links.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  ctx,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
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
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final Channel channel = await context
        .read<ChatService>()
        .joinOrCreateChannel(name);
    onOpenChannel(channel);
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final List<Channel> channels = service.channels;

    return Column(
      children: <Widget>[
        const DidYouKnowStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showJoin(context),
              icon: const Icon(Icons.add),
              label: const Text('Join or create a channel'),
            ),
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No channels yet',
                  message:
                      'Channels are open rooms anyone nearby can join by name '
                      'to talk as a group. Create one to get started.',
                )
              : ListView.separated(
                  itemCount: channels.length,
                  separatorBuilder: (_, __) => const Divider(indent: 80),
                  itemBuilder: (BuildContext context, int i) {
                    final Channel c = channels[i];
                    final Message? last = service.latestWith(c.id);
                    return ListTile(
                      onTap: () => onOpenChannel(c),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.tag, color: Colors.white),
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        last == null
                            ? 'Broadcast channel'
                            : '${last.senderId != null ? '${service.senderLabel(last.senderId!)}: ' : ''}${last.body}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: last == null
                          ? null
                          : Text(
                              relativeTime(last.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.5),
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
