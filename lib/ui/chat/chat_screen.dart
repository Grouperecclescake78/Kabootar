import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/message_bubble.dart';

/// A 1:1 conversation. Reloads history from the database and re-reads it on
/// every [ChatService] change so incoming messages and status ticks update
/// live while the screen is open.
class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.peer, super.key});

  final Contact peer;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
    final List<Message> next =
        await context.read<ChatService>().conversation(widget.peer.appId);
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
    await context.read<ChatService>().send(toId: widget.peer.appId, body: text);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final bool online = service.isOnline(widget.peer.appId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Avatar(
              initials: widget.peer.initials,
              seed: widget.peer.appId,
              online: online,
              radius: 19,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.peer.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  online ? 'In range now' : 'Not in range',
                  style: TextStyle(
                    fontSize: 12,
                    color: online
                        ? AppColors.online
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          if (!online) const _OfflineBanner(),
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Say hello',
                    message:
                        'Messages are delivered whenever this person comes '
                        'into range - even if they are offline right now.',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (BuildContext context, int i) =>
                        MessageBubble(_messages[i]),
                  ),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.accent.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Not in range. Messages will be carried by nearby phones and '
              'delivered when they reconnect.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent.withValues(alpha: 0.95),
              ),
            ),
          ),
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
                  hintText: 'Message',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                  child: Icon(Icons.arrow_upward_rounded,
                      color: scheme.onPrimary, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
