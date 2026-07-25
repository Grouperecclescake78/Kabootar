import 'package:flutter/material.dart';

/// A lightweight emoji picker shown as a bottom sheet. Tapping an emoji inserts
/// it at the cursor and keeps the sheet open so several can be added.
///
/// Note: emoji glyphs render in the device's own emoji font (on Android that is
/// the system/Noto set). Apple's emoji artwork is proprietary and cannot be
/// legally bundled, so exact iPhone glyphs are only shown on Apple devices.
Future<void> showEmojiPicker(
  BuildContext context,
  TextEditingController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _EmojiSheet(controller: controller),
  );
}

void _insert(TextEditingController c, String emoji) {
  final TextSelection sel = c.selection;
  if (sel.isValid) {
    final String next = c.text.replaceRange(sel.start, sel.end, emoji);
    c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + emoji.length),
    );
  } else {
    c.text = c.text + emoji;
    c.selection = TextSelection.collapsed(offset: c.text.length);
  }
}

class _EmojiSheet extends StatelessWidget {
  const _EmojiSheet({required this.controller});

  final TextEditingController controller;

  static const List<String> _emojis = <String>[
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🤣',
    '🙂',
    '😉',
    '😊',
    '😍',
    '😘',
    '😗',
    '😜',
    '🤪',
    '🤔',
    '😎',
    '🥳',
    '😴',
    '🤗',
    '🙃',
    '😇',
    '🤩',
    '😢',
    '😭',
    '😤',
    '😡',
    '😱',
    '😳',
    '🥺',
    '😬',
    '👍',
    '👎',
    '👌',
    '👏',
    '🙏',
    '💪',
    '🤝',
    '✌️',
    '🤞',
    '👋',
    '🤙',
    '🙌',
    '👀',
    '🧠',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '💔',
    '🔥',
    '✨',
    '⭐',
    '🎉',
    '💯',
    '✅',
    '❌',
    '❗',
    '❓',
    '💬',
    '📱',
    '📢',
    '🔒',
    '📶',
    '🔋',
    '🌐',
    '🏫',
    '🎓',
    '☕',
    '🍕',
    '🏏',
    '⚽',
    '🎮',
    '🎵',
    '🌟',
    '🌈',
    '☀️',
    '🌙',
    '🚀',
    '🇮🇳',
    '🪔',
    '🙏🏽',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Emoji',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _emojis.length,
              itemBuilder: (BuildContext context, int i) {
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _insert(controller, _emojis[i]),
                  child: Center(
                    child: Text(
                      _emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
