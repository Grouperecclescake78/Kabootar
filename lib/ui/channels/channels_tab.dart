import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../format.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';
import '../widgets/text_prompt.dart';

/// Lists the broadcast channels you have joined, and lets you create one (you
/// get a code to share) or join one with a code someone gave you.
class ChannelsTab extends StatelessWidget {
  const ChannelsTab({required this.onOpenChannel, super.key});

  final void Function(Channel) onOpenChannel;

  Future<void> _create(BuildContext context) async {
    final String? name = await promptText(
      context,
      title: 'Create a channel',
      hint: 'Channel name (e.g. Campus)',
      message: 'You will get a code to share so others can join.',
      confirmLabel: 'Create',
      maxLength: 30,
    );
    if (name == null || !context.mounted) return;
    final Channel channel =
        await context.read<ChatService>().createChannel(name);
    onOpenChannel(channel);
  }

  Future<void> _join(BuildContext context) async {
    final String? code = await promptText(
      context,
      title: 'Join a channel',
      hint: 'ABC234',
      message: 'Enter the code someone shared with you.',
      confirmLabel: 'Join',
      uppercase: true,
      maxLength: 6,
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    final Channel? channel =
        await context.read<ChatService>().joinChannelByCode(code);
    if (channel != null) onOpenChannel(channel);
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final List<Channel> channels = service.channels;

    return Column(
      children: <Widget>[
        const DidYouKnowStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _join(context),
                  icon: const Icon(Icons.tag),
                  label: const Text('Join with code'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No channels yet',
                  message:
                      'Create a channel to get a code you can share, or join '
                      'one with a code someone gave you.',
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
                        c.display,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        last == null
                            ? 'Code ${c.code}'
                            : '${last.senderId != null && last.senderId != service.identity.appId ? '${service.senderLabel(last.senderId!)}: ' : ''}${last.body}',
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
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
