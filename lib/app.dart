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

/// Root widget. Owns the async bootstrap (database + identity), routes between
/// onboarding and the live session, and provides the [ChatService] to the tree.
class StudchatApp extends StatelessWidget {
  const StudchatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studchat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<_Boot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Boot> _load() async {
    final IdentityStore store = await IdentityStore.create();
    final AppDatabase db = await AppDatabase.open();
    final Identity identity = await store.loadOrCreate();
    return _Boot(store, db, identity);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Boot>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_Boot> snap) {
        if (!snap.hasData) return const _Splash();
        final _Boot boot = snap.data!;
        if (boot.identity.name.trim().isEmpty) {
          return OnboardingScreen(
            onComplete: (String name) async {
              await boot.store.setName(name);
              setState(() {
                _future = Future<_Boot>.value(
                  _Boot(
                    boot.store,
                    boot.db,
                    boot.identity.copyWith(name: name),
                  ),
                );
              });
            },
          );
        }
        return _Session(boot: boot);
      },
    );
  }
}

/// Live session: builds and starts the [ChatService], requests radio
/// permissions, and hosts the home screen.
class _Session extends StatefulWidget {
  const _Session({required this.boot});
  final _Boot boot;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  late final ChatService _service;

  @override
  void initState() {
    super.initState();
    _service = ChatService(
      identity: widget.boot.identity,
      database: widget.boot.db,
      identityStore: widget.boot.store,
    );
    // Start the mesh in the background so the UI appears instantly; the lists
    // fill in as discovery and history-load complete (via notifyListeners).
    unawaited(_start());
  }

  Future<void> _start() async {
    await requestMeshPermissions();
    await _service.start();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatService>.value(
      value: _service,
      child: const HomeScreen(),
    );
  }
}

class _Boot {
  _Boot(this.store, this.db, this.identity);
  final IdentityStore store;
  final AppDatabase db;
  final Identity identity;
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
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
