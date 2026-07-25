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
        height: 340,
        child: EmojiPicker(
          textEditingController: controller,
          config: Config(
            height: 340,
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 26,
              backgroundColor: scheme.surface,
              recentsLimit: 32,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: scheme.surface,
              indicatorColor: scheme.primary,
              iconColorSelected: scheme.primary,
              backspaceColor: scheme.primary,
              iconColor: muted,
              dividerColor: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              buttonColor: scheme.primary,
              buttonIconColor: scheme.onPrimary,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: scheme.surface,
              buttonIconColor: muted,
            ),
          ),
        ),
      );
    },
  );
}
