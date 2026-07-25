import 'package:flutter/material.dart';

/// India's national tricolour. Non-partisan national-pride accent used to mark
/// studchat as built in India: works with no internet, no foreign servers, and
/// your data never leaves your device.
abstract class Tiranga {
  static const Color saffron = Color(0xFFFF9933);
  static const Color white = Color(0xFFFFFFFF);
  static const Color green = Color(0xFF138808);
  static const Color chakra = Color(0xFF06038D);
}

/// A slim horizontal tricolour bar with softly rounded ends.
class TricolorBar extends StatelessWidget {
  const TricolorBar({this.width = 56, this.height = 4, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: width,
        height: height,
        child: const Row(
          children: <Widget>[
            Expanded(child: ColoredBox(color: Tiranga.saffron)),
            Expanded(child: ColoredBox(color: Tiranga.white)),
            Expanded(child: ColoredBox(color: Tiranga.green)),
          ],
        ),
      ),
    );
  }
}

/// A full-width tricolour hairline, sized to sit under an [AppBar] via its
/// `bottom` slot.
class TricolorLine extends StatelessWidget implements PreferredSizeWidget {
  const TricolorLine({this.thickness = 3, super.key});

  final double thickness;

  @override
  Size get preferredSize => Size.fromHeight(thickness);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      child: const Row(
        children: <Widget>[
          Expanded(child: ColoredBox(color: Tiranga.saffron)),
          Expanded(child: ColoredBox(color: Tiranga.white)),
          Expanded(child: ColoredBox(color: Tiranga.green)),
        ],
      ),
    );
  }
}

/// "Made in India" wordmark: the tricolour bar plus a caption. Honest branding,
/// no claim of any government or third-party endorsement.
class MadeInIndia extends StatelessWidget {
  const MadeInIndia({this.caption = 'Made in India', super.key});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final Color muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const TricolorBar(),
        const SizedBox(height: 8),
        Text(
          caption,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: muted,
          ),
        ),
      ],
    );
  }
}
