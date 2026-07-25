import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/chat_service.dart';

/// Ceiling on file size sent over the mesh. Files travel as small chunks that
/// share the carry cache, so a very large file would crowd everything else out.
const int _maxFileBytes = 8 * 1024 * 1024; // 8 MB

/// Show the attachment chooser (Photo / File) for a conversation, then pick and
/// send. Shared by the 1:1 and channel chat screens.
Future<void> showAttachSheet(BuildContext context, String convId) async {
  final ChatService service = context.read<ChatService>();
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  final String? choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Photo'),
            onTap: () => Navigator.of(ctx).pop('photo'),
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: const Text('File'),
            onTap: () => Navigator.of(ctx).pop('file'),
          ),
        ],
      ),
    ),
  );

  if (choice == 'photo') {
    final XFile? x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 88,
    );
    if (x == null) return;
    final Uint8List bytes = await x.readAsBytes();
    await service.sendImage(convId: convId, bytes: bytes, name: x.name);
  } else if (choice == 'file') {
    final FilePickerResult? result =
        await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final PlatformFile f = result.files.first;
    final Uint8List? bytes = f.bytes;
    if (bytes == null) return;
    if (bytes.length > _maxFileBytes) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That file is over 8 MB - too large to carry over '
              'the mesh right now.'),
        ),
      );
      return;
    }
    await service.sendFile(convId: convId, bytes: bytes, name: f.name);
  }
}
