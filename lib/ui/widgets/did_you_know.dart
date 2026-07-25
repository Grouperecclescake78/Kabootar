import 'dart:async';

import 'package:flutter/material.dart';

import '../about/civic_content.dart';
import 'made_in_india.dart';

/// A slim, auto-rotating "Did you know?" strip with a tricolour edge. Used at
/// the top of the chat screen and the chat list so a helpful fact (about the
/// mesh or about India) is always one glance away.
class DidYouKnowStrip extends StatefulWidget {
  const DidYouKnowStrip({this.facts = Civic.facts, super.key});

  final List<String> facts;

  @override
  State<DidYouKnowStrip> createState() => _DidYouKnowStripState();
}

class _DidYouKnowStripState extends State<DidYouKnowStrip> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start at a varied index so different screens do not show the same line.
    _i = DateTime.now().second % widget.facts.length;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _i = (_i + 1) % widget.facts.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      // Fixed height for two lines, so the strip never jumps as facts of
      // different lengths rotate through.
      height: 50,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: const Border(
          left: BorderSide(color: Tiranga.saffron, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.lightbulb_outline, size: 15, color: Tiranga.green),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  key: ValueKey<int>(_i),
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.facts[_i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
