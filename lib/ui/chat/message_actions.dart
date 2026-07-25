import 'package:flutter/material.dart';

import '../../core/models/message.dart';

/// What the user picked from the message long-press sheet. The chat screen
/// owns the follow-through (confirmations, snackbars, reload) so this stays a
/// pure chooser.
enum MessageAction { copy, info, select, deleteForMe, deleteForEveryone }

/// Long-press action sheet for a single message. Delete-for-everyone is only
/// offered when [canDeleteForEveryone] is true (our own recent outgoing
/// message).
Future<MessageAction?> showMessageActions(
  BuildContext context, {
  required Message message,
  required bool canDeleteForEveryone,
  bool allowSelect = true,
}) {
  return showModalBottomSheet<MessageAction>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      final Color danger = Theme.of(ctx).colorScheme.error;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy'),
              onTap: () => Navigator.of(ctx).pop(MessageAction.copy),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Info'),
              onTap: () => Navigator.of(ctx).pop(MessageAction.info),
            ),
            if (allowSelect)
              ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: const Text('Select'),
                onTap: () => Navigator.of(ctx).pop(MessageAction.select),
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: danger),
              title: Text('Delete', style: TextStyle(color: danger)),
              onTap: () => Navigator.of(ctx).pop(MessageAction.deleteForMe),
            ),
            if (canDeleteForEveryone)
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: danger),
                title: Text(
                  'Delete for everyone',
                  style: TextStyle(color: danger),
                ),
                onTap: () =>
                    Navigator.of(ctx).pop(MessageAction.deleteForEveryone),
              ),
          ],
        ),
      );
    },
  );
}
