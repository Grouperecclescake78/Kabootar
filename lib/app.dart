import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/identity/identity.dart';
import 'data/app_database.dart';
import 'data/identity_store.dart';
import 'permissions.dart';
import 'services/chat_service.dart';
import 'theme/app_theme.dart';
import 'ui/about/civic_content.dart';
import 'ui/home/home_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/widgets/chakra.dart';
import 'ui/widgets/made_in_india.dart';

/// Root widget. Owns the async bootstrap (database + identity) and, crucially,
/// provides the [ChatService] **above** [MaterialApp] so every pushed route
/// (chats, channels, new-chat) can read it, not just the home screen.
class StudchatApp extends StatefulWidget {
  const StudchatApp({super.key});

  @override
  State<StudchatApp> createState() => _StudchatAppState();
}

class _StudchatAppState extends State<StudchatApp> {
  late final Future<_Boot> _bootFuture = _load();
  ChatService? _service;
  bool _onboarded = false;

  Future<_Boot> _load() async {
    final IdentityStore store = await IdentityStore.create();
    final AppDatabase db = await AppDatabase.open();
    final Identity identity = await store.loadOrCreate();
    return _Boot(store, db, identity);
  }

  ChatService _makeService(_Boot boot) {
    final ChatService service = ChatService(
      identity: boot.identity,
      database: boot.db,
      identityStore: boot.store,
    );
    // Start the mesh in the background so the UI appears instantly.
    unawaited(() async {
      await requestMeshPermissions();
      await service.start();
    }());
    return service;
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Boot>(
      future: _bootFuture,
      builder: (BuildContext context, AsyncSnapshot<_Boot> snap) {
        if (!snap.hasData) return _app(const _Splash());
        final _Boot boot = snap.data!;

        final bool onboarded =
            _onboarded || boot.identity.name.trim().isNotEmpty;
        if (!onboarded) {
          return _app(
            OnboardingScreen(
              onComplete: (String name) async {
                await boot.store.setName(name);
                boot.identity = boot.identity.copyWith(name: name);
                setState(() => _onboarded = true);
              },
            ),
          );
        }

        // Create the service once, and provide it ABOVE MaterialApp so pushed
        // routes can access it too.
        _service ??= _makeService(boot);
        return ChangeNotifierProvider<ChatService>.value(
          value: _service!,
          child: _app(const HomeScreen()),
        );
      },
    );
  }

  Widget _app(Widget home) => MaterialApp(
    title: 'Studchat',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: home,
  );
}

class _Boot {
  _Boot(this.store, this.db, this.identity);
  final IdentityStore store;
  final AppDatabase db;
  Identity identity;
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final String fact = Civic.facts[DateTime.now().second % Civic.facts.length];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Chakra(size: 88),
              const SizedBox(height: 22),
              const Text(
                'Studchat',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const TricolorBar(width: 90, height: 5),
              const SizedBox(height: 10),
              Text(
                'Made in India 🇮🇳',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 15,
                    color: Tiranga.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fact,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
