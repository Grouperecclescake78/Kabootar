import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

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
    this.height = 300,
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
            tabBarHeight: 46,
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primary,
            iconColorSelected: scheme.primary,
            backspaceColor: scheme.primary,
            iconColor: muted,
            dividerColor: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: scheme.surface,
            buttonColor: scheme.primary,
            buttonIconColor: scheme.onPrimary,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: scheme.surface,
            buttonIconColor: muted,
            hintText: 'Search emoji',
          ),
        ),
      ),
    );
  }
}
