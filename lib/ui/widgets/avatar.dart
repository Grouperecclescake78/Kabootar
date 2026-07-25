import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A circular initials avatar with an optional online presence dot. The colour
/// is derived from the name so a given contact is always the same hue.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.initials,
    this.online = false,
    this.radius = 24,
    this.seed,
    super.key,
  });

  final String initials;
  final bool online;
  final double radius;
  final String? seed;

  static const List<Color> _palette = <Color>[
    Color(0xFF4F46E5),
    Color(0xFF0EA5A4),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFCA8A04),
  ];

  Color get _color {
    final String key = seed ?? initials;
    if (key.isEmpty) return _palette.first;
    final int h = key.codeUnits.fold<int>(0, (int a, int c) => a + c);
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          CircleAvatar(
            radius: radius,
            backgroundColor: _color,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: radius * 0.5,
                height: radius * 0.5,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
