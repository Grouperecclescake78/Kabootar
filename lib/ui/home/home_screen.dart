import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../widgets/mesh_status_pill.dart';
import 'chats_tab.dart';
import 'mesh_tab.dart';
import 'people_tab.dart';
import 'profile_sheet.dart';

/// The app shell: a live mesh status pill in the bar, and three tabs - the
/// conversations you have, the people in range, and the mesh itself.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const List<String> _titles = <String>['Chats', 'People', 'Mesh'];

  void _openChat(Contact peer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(peer: peer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: MeshStatusPill(
                online: service.onlinePeerCount,
                carrying: service.carriedForOthers,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => showProfileSheet(context),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          ChatsTab(onOpenChat: _openChat),
          PeopleTab(onOpenChat: _openChat),
          const MeshTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: service.onlinePeerCount > 0
                ? Badge(
                    label: Text('${service.onlinePeerCount}'),
                    child: const Icon(Icons.people_outline),
                  )
                : const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: 'People',
          ),
          const NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'Mesh',
          ),
        ],
      ),
    );
  }
}
