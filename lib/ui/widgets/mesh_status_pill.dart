import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The live mesh indicator in the app bar: how many peers are in range right
/// now, and (when non-zero) how many messages this device is carrying for
/// others. A quiet, honest read on whether the mesh can move anything.
class MeshStatusPill extends StatelessWidget {
  const MeshStatusPill({
    required this.online,
    required this.carrying,
    super.key,
  });

  final int online;
  final int carrying;

  @override
  Widget build(BuildContext context) {
    final bool live = online > 0;
    final Color dot = live ? AppColors.online : Colors.grey;
    final String label = live ? '$online nearby' : 'No peers in range';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PulseDot(color: dot, pulsing: live),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (carrying > 0) ...<Widget>[
            const SizedBox(width: 8),
            const Icon(
              Icons.inventory_2_outlined,
              size: 13,
              color: AppColors.accent,
            ),
            const SizedBox(width: 3),
            Text(
              '$carrying',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.pulsing});
  final Color color;
  final bool pulsing;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) {
      return _dot(1);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) => _dot(0.4 + 0.6 * _c.value),
    );
  }

  Widget _dot(double opacity) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}
