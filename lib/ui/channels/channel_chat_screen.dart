import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';
import '../widgets/made_in_india.dart';
import '../widgets/message_bubble.dart';
import '../chat/message_actions.dart';
import '../chat/message_info_sheet.dart';
import '../chat/composer.dart';

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

  ChatService? _service;

  @override
  void initState() {
    super.initState();
    final ChatService service = context.read<ChatService>();
    _service = service;
    service.addListener(_reload);
    service.openConversationId = widget.channel.id;
    _reload();
  }

  @override
  void dispose() {
    final ChatService? service = _service;
    if (service != null) {
      service.removeListener(_reload);
      if (service.openConversationId == widget.channel.id) {
        service.openConversationId = null;
      }
    }
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

  void _shareCode() {
    Clipboard.setData(ClipboardData(text: widget.channel.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Code ${widget.channel.code} copied. Share it so others can join.',
        ),
      ),
    );
  }

  Future<void> _onMessageLongPress(Message m) async {
    final ChatService service = context.read<ChatService>();
    final MessageAction? action = await showMessageActions(
      context,
      message: m,
      canDeleteForEveryone: service.canDeleteForEveryone(m),
      allowSelect: false,
    );
    if (!mounted) return;
    switch (action) {
      case MessageAction.copy:
        Clipboard.setData(ClipboardData(text: m.body));
        _snack('Copied');
      case MessageAction.info:
        await showMessageInfo(context, m);
      case MessageAction.deleteForMe:
        if (await _confirm('Delete message?',
            'It will be removed from this device.', 'Delete')) {
          await service.deleteMessages(<String>[m.id]);
          await _reload();
        }
      case MessageAction.deleteForEveryone:
        if (await _confirm(
            'Delete for everyone?',
            'It will be removed for you and, once they are in range, for '
                'everyone in the channel.',
            'Delete for everyone')) {
          await service.deleteForEveryone(m);
          await _reload();
        }
      case MessageAction.select:
      case null:
        break;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  Future<void> _leave() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Leave ${widget.channel.display}?'),
        content: const Text(
          'You will stop receiving messages from this channel. You can rejoin '
          'any time with its code.',
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
                    widget.channel.display,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Code ${widget.channel.code} · ${service.onlinePeerCount} nearby',
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
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20),
            tooltip: 'Share code',
            onPressed: _shareCode,
          ),
          PopupMenuButton<String>(
            onSelected: (String v) {
              if (v == 'leave') _leave();
              if (v == 'code') _shareCode();
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'code',
                child: Text('Copy channel code'),
              ),
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
                        'Share the code ${widget.channel.code} so others can '
                        'join. Anyone nearby who enters it sees what you post '
                        'here. Say something!',
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
                        onLongPress: () => _onMessageLongPress(m),
                      );
                    },
                  ),
          ),
          Composer(
              controller: _input, onSend: _send, hint: 'Message the channel'),
        ],
      ),
    );
  }
}
