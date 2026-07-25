import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/channel.dart';
import '../../core/models/contact.dart';
import '../../services/chat_service.dart';
import '../channels/channel_chat_screen.dart';
import '../channels/channels_tab.dart';
import '../chat/chat_screen.dart';
import '../chat/new_chat_screen.dart';
import '../../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/chakra.dart';
import '../widgets/made_in_india.dart';
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
            // The landing tab is branded 'Kabootar'; the others keep their name.
            Text(_tab == 0 ? 'Kabootar' : _titles[_tab]),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: service.onlinePeerCount > 0
                ? '${service.onlinePeerCount} nearby'
                : 'No peers in range',
            onPressed: () => setState(() => _tab = 3),
            icon: Badge(
              isLabelVisible: service.onlinePeerCount > 0,
              label: Text('${service.onlinePeerCount}'),
              child: Icon(
                Icons.hub_outlined,
                color: service.onlinePeerCount > 0
                    ? AppColors.online
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: GestureDetector(
              onTap: () => showProfileSheet(context),
              child: Avatar(
                initials: service.selfContact.initials,
                seed: service.identity.appId,
                radius: 17,
              ),
            ),
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
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NewChatScreen()),
              ),
              tooltip: 'New chat',
              child: const Icon(Icons.chat_outlined),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: service.unreadCount > 0
                ? Badge(
                    label: Text('${service.unreadCount}'),
                    child: const Icon(Icons.chat_bubble_outline),
                  )
                : const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
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
