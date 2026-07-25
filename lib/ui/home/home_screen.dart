import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../channels/channel_chat_screen.dart';
import '../channels/channels_tab.dart';
import '../chat/chat_screen.dart';
import '../widgets/chakra.dart';
import '../widgets/made_in_india.dart';
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

  static const List<String> _titles = <String>[
    'Chats',
    'People',
    'Channels',
    'Mesh',
  ];

  void _openChat(Contact peer) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(peer: peer)));
  }

  void _openChannel(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelChatScreen(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            const Chakra(size: 24),
            const SizedBox(width: 10),
            Text(_titles[_tab]),
          ],
        ),
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
        bottom: const TricolorLine(),
      ),
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          ChatsTab(onOpenChat: _openChat),
          PeopleTab(onOpenChat: _openChat),
          ChannelsTab(onOpenChannel: _openChannel),
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
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Channels',
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
