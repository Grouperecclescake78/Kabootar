import 'package:flutter/material.dart';

import 'emoji_picker.dart';

/// The message input bar, shared by 1:1 and channel chats: a single rounded
/// input pill with an emoji button, and a circular send button that lights up
/// when there is something to send.
class Composer extends StatefulWidget {
  const Composer({
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.hint = 'Message',
    super.key,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;

  /// Optional handler for the attach (image) button; hidden when null.
  final VoidCallback? onAttach;
  final String hint;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final bool has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () =>
                          showEmojiPicker(context, widget.controller),
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        size: 24,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: 'Emoji',
                    ),
                    if (widget.onAttach != null)
                      IconButton(
                        onPressed: widget.onAttach,
                        icon: Icon(
                          Icons.image_outlined,
                          size: 23,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 40,
                        ),
                        tooltip: 'Send a photo',
                      ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => widget.onSend(),
                        style: const TextStyle(fontSize: 15.5, height: 1.3),
                        cursorColor: scheme.primary,
                        // Override the global filled input theme so no inner
                        // rectangle shows inside the pill.
                        decoration: InputDecoration(
                          filled: false,
                          isCollapsed: true,
                          hintText: widget.hint,
                          hintStyle: TextStyle(
                            fontSize: 15.5,
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            4,
                            12,
                            12,
                            12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(active: _hasText, onTap: widget.onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.active, required this.onTap});

  final bool active;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 46,
      height: 46,
      child: Material(
        color: active ? scheme.primary : scheme.primary.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: active ? onTap : null,
          child: Icon(
            Icons.arrow_upward_rounded,
            color: scheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
