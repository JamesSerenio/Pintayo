import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/friends/application/request_attention.dart';
import '../../features/friends/data/friends_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_spacing.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/friends/presentation/pages/friends_page.dart';
import '../../features/chat/presentation/pages/chats_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

class AdaptiveAppShell extends ConsumerWidget {
  final String tab;
  final bool showRequests;
  const AdaptiveAppShell({
    super.key,
    required this.tab,
    this.showRequests = false,
  });
  static const tabs = ['map', 'friends', 'chats', 'profile'];
  static const labels = ['Map', 'Friends', 'Chats', 'Profile'];
  static const icons = [
    Icons.map_outlined,
    Icons.people_outline,
    Icons.chat_bubble_outline,
    Icons.person_outline,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = (ref.watch(friendsProvider).asData?.value ?? [])
        .where((f) => f.incoming && !f.accepted)
        .map((f) => f.id)
        .toList();
    final attention = ref.watch(requestAttentionProvider);
    final unread = (ref.watch(conversationsProvider).asData?.value ?? [])
        .fold<int>(0, (sum, chat) => sum + chat.unread);
    void navigate(int i) {
      if (i == 1) attention.mark('friends', requests);
      context.go('/${tabs[i]}');
    }

    Widget navIcon(int i) => ListenableBuilder(
      listenable: attention,
      builder: (_, _) {
        final count = i == 1
            ? attention.count('friends', requests)
            : i == 2
            ? unread
            : 0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(icons[i]),
        );
      },
    );
    final index = tabs.contains(tab) ? tabs.indexOf(tab) : 0;
    final panel = switch (index) {
      1 => FriendsPage(
        key: ValueKey(showRequests),
        initialTab: showRequests ? 1 : 0,
      ),
      2 => const ChatsPage(),
      3 => const ProfilePage(),
      _ => const MapPage(),
    };
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) {
            if (constraints.maxWidth < AppSpacing.tabletBreakpoint) {
              return panel;
            }
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Icon(Icons.location_on, size: 36),
                  ),
                  onDestinationSelected: navigate,
                  destinations: [
                    for (var i = 0; i < tabs.length; i++)
                      NavigationRailDestination(
                        icon: navIcon(i),
                        label: Text(labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: MapPage()),
                SizedBox(
                  width: AppSpacing.panelWidth,
                  child: index == 0 ? const FriendsPage() : panel,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar:
          MediaQuery.sizeOf(context).width >= AppSpacing.tabletBreakpoint
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: navigate,
              destinations: [
                for (var i = 0; i < tabs.length; i++)
                  NavigationDestination(icon: navIcon(i), label: labels[i]),
              ],
            ),
    );
  }
}
