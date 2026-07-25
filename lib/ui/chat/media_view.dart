import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/models/message.dart';

/// Renders an image message inside a chat bubble: the full image once it has
/// downloaded, otherwise the thumbnail with a "receiving" or "failed" overlay.
/// Tapping a complete image opens it full-screen.
class MediaImage extends StatelessWidget {
  const MediaImage({required this.message, super.key});

  final Message message;

  bool get _complete =>
      message.mediaStatus == 'complete' &&
      message.mediaPath != null &&
      File(message.mediaPath!).existsSync();

  bool get _failed => message.mediaStatus == 'failed';

  @override
  Widget build(BuildContext context) {
    final String? thumb = message.thumb;
    Widget image;
    if (_complete) {
      image = Image.file(File(message.mediaPath!), fit: BoxFit.cover);
    } else if (thumb != null && thumb.isNotEmpty) {
      image = Image.memory(base64Url.decode(thumb), fit: BoxFit.cover);
    } else {
      image = Container(
        color: Colors.black26,
        alignment: Alignment.center,
        child:
            const Icon(Icons.image_outlined, color: Colors.white70, size: 40),
      );
    }

    return GestureDetector(
      onTap: _complete
          ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FullScreenImage(path: message.mediaPath!),
                ),
              )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 240,
            maxHeight: 340,
            minWidth: 160,
            minHeight: 120,
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              image,
              if (!_complete)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black38),
                    child: Center(
                      child: _failed
                          ? const _Overlay(
                              icon: Icons.broken_image_outlined,
                              label: 'Not delivered',
                            )
                          : const _Overlay(
                              icon: null,
                              label: 'Receiving…',
                              spinner: true,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay(
      {required this.icon, required this.label, this.spinner = false});

  final IconData? icon;
  final String label;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (spinner)
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: Colors.white),
          )
        else if (icon != null)
          Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// A file attachment card: icon, name and size (or transfer state). Tapping a
/// completed file opens it with the system's default app.
class FileMessage extends StatelessWidget {
  const FileMessage({required this.message, required this.color, super.key});

  final Message message;
  final Color color;

  bool get _complete =>
      message.mediaStatus == 'complete' &&
      message.mediaPath != null &&
      File(message.mediaPath!).existsSync();

  @override
  Widget build(BuildContext context) {
    final bool failed = message.mediaStatus == 'failed';
    final String subtitle = failed
        ? 'Not delivered'
        : _complete
            ? _sizeLabel(message.mediaBytes)
            : 'Receiving…';

    return InkWell(
      onTap: _complete ? () => OpenFilex.open(message.mediaPath!) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                failed
                    ? Icons.error_outline
                    : _complete
                        ? Icons.insert_drive_file_outlined
                        : Icons.downloading_outlined,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.mediaName ?? 'File',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sizeLabel(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
