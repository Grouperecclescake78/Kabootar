import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../core/models/message.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/did_you_know.dart';
import '../widgets/empty_state.dart';
import '../widgets/made_in_india.dart';
import '../widgets/message_bubble.dart';
import 'attach.dart';
import 'composer.dart';
import 'message_actions.dart';
import 'message_info_sheet.dart';

/// A 1:1 conversation. Reloads history from the database and re-reads it on
/// every [ChatService] change so incoming messages and status ticks update
/// live while the screen is open. Long-press a message for actions (copy,
/// delete, delete for everyone) or to start a multi-select.
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

  /// Ids selected in multi-select mode; empty means normal mode.
  final Set<String> _selected = <String>{};
  bool get _selecting => _selected.isNotEmpty;

  ChatService? _service;

  @override
  void initState() {
    super.initState();
    final ChatService service = context.read<ChatService>();
    _service = service;
    service.addListener(_reload);
    // Mark this conversation as on-screen so its messages don't notify, and
    // clear any unread flag now that we are looking at it.
    service.openConversationId = widget.peer.appId;
    service.clearUnread(widget.peer.appId);
    _reload();
  }

  @override
  void dispose() {
    final ChatService? service = _service;
    if (service != null) {
      service.removeListener(_reload);
      if (service.openConversationId == widget.peer.appId) {
        service.openConversationId = null;
      }
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final ChatService service = context.read<ChatService>();
    final List<Message> next = await service.conversation(widget.peer.appId);
    if (!mounted) return;
    setState(() {
      _messages = next;
      // Drop any selected ids that no longer exist (e.g. after a delete).
      final Set<String> live = next.map((Message m) => m.id).toSet();
      _selected.retainAll(live);
    });
    // We are looking at this conversation, so tell the sender we have read it.
    service.markConversationRead(widget.peer.appId);
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

  Future<void> _attach() async {
    await showAttachSheet(context, widget.peer.appId);
    await _reload();
  }

  // --- Selection -----------------------------------------------------------

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  List<Message> get _selectedMessages =>
      _messages.where((Message m) => _selected.contains(m.id)).toList();

  // --- Actions -------------------------------------------------------------

  Future<void> _onBubbleTap(Message m) async {
    if (_selecting) {
      _toggle(m.id);
      return;
    }
    final ChatService service = context.read<ChatService>();
    final MessageAction? action = await showMessageActions(
      context,
      message: m,
      canDeleteForEveryone: service.canDeleteForEveryone(m),
    );
    if (!mounted) return;
    switch (action) {
      case MessageAction.copy:
        _copy(m.body);
      case MessageAction.info:
        await showMessageInfo(context, m);
      case MessageAction.select:
        _toggle(m.id);
      case MessageAction.deleteForMe:
        await _deleteOne(m);
      case MessageAction.deleteForEveryone:
        await _deleteEveryone(m);
      case null:
        break;
    }
  }

  Future<void> _deleteOne(Message m) async {
    final ChatService service = context.read<ChatService>();
    final bool ok = await _confirm(
      title: 'Delete message?',
      message: 'It will be removed from this device.',
      action: 'Delete',
    );
    if (!ok) return;
    await service.deleteMessages(<String>[m.id]);
    await _reload();
  }

  Future<void> _deleteEveryone(Message m) async {
    final ChatService service = context.read<ChatService>();
    final bool ok = await _confirm(
      title: 'Delete for everyone?',
      message: 'This message will be removed for you and, once they are in '
          'range, for everyone who received it.',
      action: 'Delete for everyone',
    );
    if (!ok) return;
    await service.deleteForEveryone(m);
    await _reload();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Copied');
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteSelected() async {
    final ChatService service = context.read<ChatService>();
    final int n = _selected.length;
    final bool ok = await _confirm(
      title: n == 1 ? 'Delete message?' : 'Delete $n messages?',
      message: 'They will be removed from this device.',
      action: 'Delete',
    );
    if (!ok) return;
    await service.deleteMessages(_selected.toList());
    _clearSelection();
    await _reload();
  }

  void _copySelected() {
    final List<Message> msgs = _selectedMessages
      ..sort((Message a, Message b) => a.timestamp.compareTo(b.timestamp));
    _copy(msgs.map((Message m) => m.body).join('\n'));
    _clearSelection();
  }

  Future<void> _clearChat() async {
    final ChatService service = context.read<ChatService>();
    final bool ok = await _confirm(
      title: 'Clear chat?',
      message: 'Every message in this conversation will be deleted from this '
          'device. This cannot be undone.',
      action: 'Clear',
    );
    if (!ok) return;
    await service.clearChat(widget.peer.appId);
    await _reload();
  }

  Future<void> _deleteChat() async {
    final ChatService service = context.read<ChatService>();
    final bool ok = await _confirm(
      title: 'Delete chat?',
      message: 'This conversation and its messages will be removed from this '
          'device.',
      action: 'Delete',
    );
    if (!ok) return;
    await service.deleteChat(widget.peer.appId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showSafetyCode() async {
    final Future<String>? future =
        context.read<ChatService>().safetyCodeWith(widget.peer.appId);
    if (future == null) {
      _snack('No encryption keys for this contact yet');
      return;
    }
    final String code = await future;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.verified_user_outlined, size: 20),
            SizedBox(width: 8),
            Text('Safety code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Messages with ${widget.peer.name} are end-to-end encrypted. '
              'Compare this code with them in person or over another channel - '
              'if it matches on both phones, no one is in the middle.',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            Center(
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlock(bool blocked) async {
    final ChatService service = context.read<ChatService>();
    if (blocked) {
      final bool ok = await _confirm(
        title: 'Block ${widget.peer.name}?',
        message: 'You will stop receiving their messages. You can unblock them '
            'later.',
        action: 'Block',
      );
      if (!ok) return;
    }
    await service.blockContact(widget.peer.appId, blocked: blocked);
    _snack(blocked ? 'Blocked' : 'Unblocked');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
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

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();
    final bool self = service.isSelf(widget.peer.appId);
    final bool online = !self && service.isOnline(widget.peer.appId);
    final bool blocked = !self && service.isBlocked(widget.peer.appId);

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && _selecting) _clearSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionAppBar()
            : _chatAppBar(service,
                self: self, online: online, blocked: blocked),
        body: Column(
          children: <Widget>[
            const DidYouKnowStrip(),
            if (blocked) const _BlockedBanner(),
            if (!online && !self && !blocked) const _OfflineBanner(),
            Expanded(
              child: _messages.isEmpty
                  ? EmptyState(
                      icon: self
                          ? Icons.bookmark_outline
                          : Icons.waving_hand_outlined,
                      title: self ? 'Notes to self' : 'Say hello',
                      message: self
                          ? 'Jot down notes, links and reminders. These stay on '
                              'this device and are never sent over the mesh.'
                          : 'Messages are delivered whenever this person comes '
                              'into range - even if they are offline right now.',
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Message m = _messages[i];
                        return MessageBubble(
                          m,
                          selected: _selected.contains(m.id),
                          onTap: () => _onBubbleTap(m),
                          onLongPress: () =>
                              _selecting ? _toggle(m.id) : _onBubbleTap(m),
                        );
                      },
                    ),
            ),
            Composer(
              controller: _input,
              onSend: _send,
              onAttach: _attach,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _chatAppBar(
    ChatService service, {
    required bool self,
    required bool online,
    required bool blocked,
  }) {
    final bool encrypted = !self && service.isEncryptedWith(widget.peer.appId);
    final String subtitle = self
        ? 'Message yourself · saved on this device'
        : blocked
            ? 'Blocked'
            : (online ? 'In range now' : 'Not in range');
    final Color subtitleColor = online
        ? AppColors.online
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return AppBar(
      titleSpacing: 0,
      bottom: const TricolorLine(),
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
                self ? '${widget.peer.name} (You)' : widget.peer.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (encrypted) ...<Widget>[
                    Icon(Icons.lock, size: 12, color: subtitleColor),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        PopupMenuButton<String>(
          onSelected: (String v) {
            switch (v) {
              case 'safety':
                _showSafetyCode();
              case 'clear':
                _clearChat();
              case 'delete':
                _deleteChat();
              case 'block':
                _toggleBlock(!service.isBlocked(widget.peer.appId));
            }
          },
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            if (encrypted)
              const PopupMenuItem<String>(
                value: 'safety',
                child: _MenuRow(Icons.verified_user_outlined, 'Safety code'),
              ),
            const PopupMenuItem<String>(
              value: 'clear',
              child: _MenuRow(Icons.cleaning_services_outlined, 'Clear chat'),
            ),
            if (!self)
              PopupMenuItem<String>(
                value: 'block',
                child: _MenuRow(
                  service.isBlocked(widget.peer.appId)
                      ? Icons.lock_open_outlined
                      : Icons.block,
                  service.isBlocked(widget.peer.appId) ? 'Unblock' : 'Block',
                ),
              ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: _MenuRow(Icons.delete_outline, 'Delete chat'),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    return AppBar(
      bottom: const TricolorLine(),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
        tooltip: 'Cancel',
      ),
      title: Text('${_selected.length} selected'),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          onPressed: _copySelected,
          tooltip: 'Copy',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deleteSelected,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
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
          const Icon(
            Icons.inventory_2_outlined,
            size: 15,
            color: AppColors.accent,
          ),
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

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner();

  @override
  Widget build(BuildContext context) {
    final Color red = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      color: red.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.block, size: 15, color: red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You blocked this contact. Their new messages are not delivered. '
              'Use the menu to unblock.',
              style:
                  TextStyle(fontSize: 12, color: red.withValues(alpha: 0.95)),
            ),
          ),
        ],
      ),
    );
  }
}
