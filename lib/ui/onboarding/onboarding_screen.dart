import 'package:flutter/material.dart';

import '../about/about_screen.dart';
import '../widgets/chakra.dart';
import '../widgets/made_in_india.dart';

/// First-launch screen: pick a display name. The stable app id is minted
/// silently underneath - the user only ever chooses how they appear to peers.
///
/// The layout is scroll-safe: on a short viewport (landscape, split-screen, a
/// raised keyboard) it scrolls instead of overflowing, and on a tall viewport
/// it spreads to fill the height.
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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 24),
                      const Spacer(flex: 2),
                      const _TricolorHero(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const Text(
                            'studchat',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Tiranga.saffron.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '🇮🇳 Made in India',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Tiranga.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Messaging that keeps working when the network does '
                        'not. Your messages hop phone to phone over Bluetooth '
                        'and Wi-Fi - no servers, no internet, and your data '
                        'never leaves your device.',
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
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Stays on your device. No phone number, no '
                              'account, no sign-up.',
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Start messaging'),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: 'By continuing, you agree to our ',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                            children: const <TextSpan>[
                              TextSpan(
                                text: 'Terms, Privacy & civic note',
                                style: TextStyle(
                                  color: Tiranga.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(child: MadeInIndia()),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The tricolour brand hero: the Ashoka Chakra set in a soft saffron-to-green
/// card. National pride, front and centre.
class _TricolorHero extends StatelessWidget {
  const _TricolorHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Tiranga.saffron.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
            Tiranga.green.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Tiranga.saffron.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Tiranga.chakra.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(child: Chakra(size: 62)),
    );
  }
}
