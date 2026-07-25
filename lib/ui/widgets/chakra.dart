import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'made_in_india.dart';

/// The Ashoka Chakra: the 24-spoke navy-blue wheel at the centre of the Indian
/// national flag, a symbol of dharma and ceaseless motion.
///
/// This is drawn respectfully and used only as a mark of national pride. Note
/// we deliberately never render the State Emblem (the Lion Capital of Ashoka),
/// whose use is reserved for government authorities under the State Emblem of
/// India (Prohibition of Improper Use) Act, 2005.
class Chakra extends StatelessWidget {
  const Chakra({this.size = 72, this.color, super.key});

  final double size;

  /// Override colour. When null, adapts to the theme: navy on light surfaces,
  /// a light indigo on dark surfaces so the wheel is always visible.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color c = color ?? (dark ? const Color(0xFFA5B4FC) : Tiranga.chakra);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ChakraPainter(c)),
    );
  }
}

class _ChakraPainter extends CustomPainter {
  _ChakraPainter(this.color);

  final Color color;
  static const int spokes = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;
    final double stroke = math.max(1.2, size.width * 0.028);

    final Paint line = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Outer rim.
    canvas.drawCircle(c, r - stroke, line);
    // Inner hub.
    canvas.drawCircle(c, r * 0.11, Paint()..color = color);

    // 24 spokes, each with a small rim dot at its tip.
    final Paint dot = Paint()..color = color;
    for (int i = 0; i < spokes; i++) {
      final double a = (2 * math.pi / spokes) * i;
      final Offset inner = c + Offset(math.cos(a), math.sin(a)) * (r * 0.14);
      final Offset outer = c + Offset(math.cos(a), math.sin(a)) * (r - stroke);
      canvas.drawLine(inner, outer, line);
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r * 0.82),
        stroke * 0.9,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_ChakraPainter old) => old.color != color;
}
