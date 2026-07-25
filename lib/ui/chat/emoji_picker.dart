import 'dart:convert';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pre-populate the "Recent" tab with ten common emojis so it is not empty on
/// first use. No-op once the user has their own recents. Written in the exact
/// shape emoji_picker_flutter reads (a list of {emoji, counter}); the package's
/// static cache is invalidated so a freshly-opened panel picks it up.
Future<void> seedDefaultRecentEmojis() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  const String key = 'recent';

  // Only seed when there are no usable recents yet.
  final String? existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) {
    try {
      if ((jsonDecode(existing) as List<dynamic>).isNotEmpty) return;
    } catch (_) {
      // Corrupt value: fall through and reseed.
    }
  }

  const List<List<String>> defaults = <List<String>>[
    <String>['😂', 'Face with Tears of Joy'],
    <String>['❤️', 'Red Heart'],
    <String>['👍', 'Thumbs Up'],
    <String>['🙏', 'Folded Hands'],
    <String>['🔥', 'Fire'],
    <String>['😊', 'Smiling Face with Smiling Eyes'],
    <String>['🎉', 'Party Popper'],
    <String>['😍', 'Smiling Face with Heart-Eyes'],
    <String>['💯', 'Hundred Points'],
    <String>['👏', 'Clapping Hands'],
  ];
  final List<Map<String, Object?>> recents = <Map<String, Object?>>[
    for (int i = 0; i < defaults.length; i++)
      <String, Object?>{
        'emoji': <String, Object?>{
          'emoji': defaults[i][0],
          'name': defaults[i][1],
          'hasSkinTone': false,
        },
        'counter': defaults.length - i,
      },
  ];
  await prefs.setString(key, jsonEncode(recents));
}

/// An inline emoji panel that sits where the keyboard would be, so the message
/// box stays visible above it (Gboard/WhatsApp style) rather than a modal sheet
/// that covers the composer. A **Recently used** tab plus the usual categories
/// and search; tapping inserts at the cursor.
///
/// Glyphs render in the bundled Twemoji set so they look identical on every
/// device.
class EmojiPanel extends StatelessWidget {
  const EmojiPanel({
    required this.controller,
    this.height = 320,
    super.key,
  });

  final TextEditingController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color muted = scheme.onSurface.withValues(alpha: 0.45);
    return SizedBox(
      height: height,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(
          height: height,
          checkPlatformCompatibility: false,
          emojiTextStyle: const TextStyle(fontFamily: 'Twemoji'),
          // Gboard-style order: search on top, emoji grid in the middle, the
          // category strip along the bottom (thumb-reachable).
          viewOrderConfig: const ViewOrderConfig(
            top: EmojiPickerItem.searchBar,
            middle: EmojiPickerItem.emojiView,
            bottom: EmojiPickerItem.categoryBar,
          ),
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28,
            verticalSpacing: 6,
            horizontalSpacing: 4,
            gridPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: scheme.surface,
            recentsLimit: 40,
            buttonMode: ButtonMode.MATERIAL,
          ),
          categoryViewConfig: CategoryViewConfig(
            tabBarHeight: 44,
            // Show the delete (backspace) button at the end of the category
            // strip - the bottom action bar that normally holds it is hidden in
            // this Gboard-style layout.
            extraTab: CategoryExtraTab.BACKSPACE,
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primary,
            iconColorSelected: scheme.primary,
            backspaceColor: scheme.primary,
            iconColor: muted,
            dividerColor: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: scheme.surface,
            buttonIconColor: scheme.primary,
            hintText: 'Search emoji',
          ),
        ),
      ),
    );
  }
}
