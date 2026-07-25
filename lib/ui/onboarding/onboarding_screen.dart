import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// First-launch screen: pick a display name. The stable app id is minted
/// silently underneath - the user only ever chooses how they appear to peers.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  /// Called with the chosen display name once the user taps through.
  final Future<void> Function(String name) onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    await widget.onComplete(name);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(flex: 2),
              _Logo(color: scheme.primary),
              const SizedBox(height: 28),
              const Text(
                'studchat',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Messaging that keeps working when the network does not. '
                'Your messages hop phone to phone over Bluetooth and Wi-Fi, '
                'no servers, no signal required.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const Spacer(flex: 2),
              Text(
                'Your display name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                maxLength: 24,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'e.g. Alex',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Icons.lock_outline,
                      size: 14, color: scheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Stays on your device. No phone number, no account, '
                      'no sign-up.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Start messaging'),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.hub_rounded, color: Colors.white, size: 40),
    );
  }
}
