import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';

enum _ConvAction {
  archive,
  unarchive,
  hide,
  unhide,
  clear,
  block,
  unblock,
  delete
}

/// Long-press action sheet for a conversation in a list: archive/unarchive,
/// hide, clear, block/unblock, delete. Shared by the Chats tab and the
/// Archived screen. Runs the chosen action itself (with confirmations for the
/// destructive ones).
Future<void> showConversationActions(BuildContext context, Contact c) async {
  final ChatService service = context.read<ChatService>();
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool self = service.isSelf(c.appId);
  final bool archived = service.isArchived(c.appId);
  final bool hidden = service.isHidden(c.appId);
  final bool blocked = service.isBlocked(c.appId);
  final Color danger = Theme.of(context).colorScheme.error;

  final _ConvAction? action = await showModalBottomSheet<_ConvAction>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                self ? '${c.name} (You)' : c.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            title: Text(archived ? 'Unarchive chat' : 'Archive chat'),
            onTap: () => Navigator.of(ctx).pop(
              archived ? _ConvAction.unarchive : _ConvAction.archive,
            ),
          ),
          if (hidden)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Unhide chat'),
              onTap: () => Navigator.of(ctx).pop(_ConvAction.unhide),
            )
          else if (!archived)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide chat'),
              onTap: () => Navigator.of(ctx).pop(_ConvAction.hide),
            ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear chat'),
            onTap: () => Navigator.of(ctx).pop(_ConvAction.clear),
          ),
          if (!self)
            ListTile(
              leading: Icon(blocked ? Icons.lock_open_outlined : Icons.block),
              title: Text(blocked ? 'Unblock' : 'Block'),
              onTap: () => Navigator.of(ctx).pop(
                blocked ? _ConvAction.unblock : _ConvAction.block,
              ),
            ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: danger),
            title: Text('Delete chat', style: TextStyle(color: danger)),
            onTap: () => Navigator.of(ctx).pop(_ConvAction.delete),
          ),
        ],
      ),
    ),
  );
  if (action == null) return;

  void snack(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  switch (action) {
    case _ConvAction.archive:
      await service.archiveChat(c.appId, archived: true);
      snack('Chat archived');
    case _ConvAction.unarchive:
      await service.archiveChat(c.appId, archived: false);
      snack('Chat unarchived');
    case _ConvAction.hide:
      await service.hideChat(c.appId, hidden: true);
      snack('Chat hidden. Find it in your profile under Hidden chats.');
    case _ConvAction.unhide:
      await service.hideChat(c.appId, hidden: false);
      snack('Chat unhidden');
    case _ConvAction.unblock:
      await service.blockContact(c.appId, blocked: false);
      snack('Unblocked');
    case _ConvAction.clear:
      if (!context.mounted) return;
      if (await _confirm(context, 'Clear chat?',
          'Every message here will be deleted from this device.', 'Clear')) {
        await service.clearChat(c.appId);
        snack('Chat cleared');
      }
    case _ConvAction.block:
      if (!context.mounted) return;
      if (await _confirm(
          context,
          'Block ${c.name}?',
          'You will stop receiving their messages. You can unblock later.',
          'Block')) {
        await service.blockContact(c.appId, blocked: true);
        snack('Blocked');
      }
    case _ConvAction.delete:
      if (!context.mounted) return;
      if (await _confirm(
          context,
          'Delete chat?',
          'This conversation and its messages will be removed from this '
              'device.',
          'Delete')) {
        await service.deleteChat(c.appId);
        snack('Chat deleted');
      }
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
  String action,
) async {
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
