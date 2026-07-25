import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';
import '../widgets/made_in_india.dart';
import '../widgets/message_bubble.dart';

/// A broadcast channel conversation. Messages are flooded to everyone nearby
/// who has joined the same channel. Incoming bubbles are labelled with who sent
/// them.
class ChannelChatScreen extends StatefulWidget {
  const ChannelChatScreen({required this.channel, super.key});

  final Channel channel;

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Message> _messages = <Message>[];

  @override
  void initState() {
    super.initState();
    context.read<ChatService>().addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    context.read<ChatService>().removeListener(_reload);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final List<Message> next = await context.read<ChatService>().conversation(
      widget.channel.id,
    );
    if (!mounted) return;
    setState(() => _messages = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await context.read<ChatService>().sendToChannel(
      channelId: widget.channel.id,
      body: text,
    );
    await _reload();
  }

  Future<void> _leave() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Leave ${widget.channel.display}?'),
        content: const Text(
          'You will stop receiving messages from this channel. You can rejoin '
          'any time by its name.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && mounted) {
      await context.read<ChatService>().leaveChannel(widget.channel.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        bottom: const TricolorLine(),
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.tag, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.channel.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${service.onlinePeerCount} nearby · broadcast channel',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String v) {
              if (v == 'leave') _leave();
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'leave',
                child: Text('Leave channel'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const DidYouKnowStrip(),
          Expanded(
            child: _messages.isEmpty
                ? EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Welcome to ${widget.channel.display}',
                    message:
                        'Anyone nearby who joins "${widget.channel.name}" will '
                        'see what you post here. Say something!',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (BuildContext context, int i) {
                      final Message m = _messages[i];
                      return MessageBubble(
                        m,
                        senderName: m.isIncoming && m.senderId != null
                            ? service.senderLabel(m.senderId!)
                            : null,
                      );
                    },
                  ),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message the channel',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
