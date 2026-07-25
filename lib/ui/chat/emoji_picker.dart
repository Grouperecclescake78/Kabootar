import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// A full emoji picker shown as a bottom sheet: a **Recently used** tab plus
/// the usual categories (smileys, people, animals, food, activities, travel,
/// objects, symbols, flags) and search. Tapping inserts at the cursor.
///
/// Note on style: glyphs render in the device's own emoji font. On Android that
/// is Google/Noto; Apple's emoji artwork is proprietary and cannot be legally
/// bundled, so exact iPhone glyphs only appear on Apple devices.
Future<void> showEmojiPicker(
  BuildContext context,
  TextEditingController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final Color muted = scheme.onSurface.withValues(alpha: 0.45);
      return SizedBox(
        height: 380,
        child: EmojiPicker(
          textEditingController: controller,
          config: Config(
            height: 380,
            // We bundle Twemoji, which has every glyph, so do not filter by
            // what the platform font can render.
            checkPlatformCompatibility: false,
            emojiTextStyle: const TextStyle(fontFamily: 'Twemoji'),
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 28,
              verticalSpacing: 6,
              horizontalSpacing: 4,
              gridPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              backgroundColor: scheme.surface,
              recentsLimit: 40,
              buttonMode: ButtonMode.MATERIAL,
            ),
            categoryViewConfig: CategoryViewConfig(
              tabBarHeight: 48,
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
    },
  );
}
