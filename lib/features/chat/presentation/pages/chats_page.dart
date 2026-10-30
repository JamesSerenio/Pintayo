import '../../../friends/data/friends_repository.dart';
import '../../../presence/application/online_friends.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/time_labels.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../data/chat_repository.dart';

class ChatsPage extends ConsumerWidget {
  const ChatsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineFriendsProvider).asData?.value ?? <String>{};
    final activeFriends = (ref.watch(friendsProvider).asData?.value ?? [])
        .where((f) => f.accepted && online.contains(f.person.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Conversations',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (activeFriends.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Active now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              itemCount: activeFriends.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (_, index) {
                final person = activeFriends[index].person;
                return SizedBox(
                  width: 72,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => runAction(context, () async {
                      final id = await ref
                          .read(chatRepositoryProvider)
                          .open(person.id);
                      if (context.mounted) context.push('/chat/$id');
                    }),
                    child: Column(
                      children: [
                        _OnlineAvatar(
                          name: person.displayName,
                          path: person.avatarPath,
                          online: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          person.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        Expanded(
          child: ref
              .watch(conversationsProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ErrorView(
                  onRetry: () => ref.invalidate(conversationsProvider),
                ),
                data: (chats) => chats.isEmpty
                    ? EmptyView(
                        icon: Icons.chat_bubble_outline,
                        title: 'A hello goes a long way',
                        description:
                            'Open a friend’s profile to start a conversation.',
                        action: FilledButton(
                          onPressed: () => context.go('/friends'),
                          child: const Text('Find your people'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.refresh(conversationsProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: chats.length,
                          itemBuilder: (_, index) {
                            final chat = chats[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: _OnlineAvatar(
                                  name: chat.friend?.displayName ?? '?',
                                  path: chat.friend?.avatarPath,
                                  online: online.contains(chat.friend?.id),
                                ),
                                title: Text(
                                  chat.friend?.displayName ?? 'PinTayo member',
                                  style: TextStyle(
                                    fontWeight: chat.unread > 0
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  chat.preview,
                                  style: TextStyle(
                                    fontWeight: chat.unread > 0
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: chat.unread > 0
                                        ? AppColors.navy
                                        : AppColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      timeAgo(chat.updatedAt),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                    if (chat.unread > 0)
                                      Badge(label: Text('${chat.unread}')),
                                  ],
                                ),
                                onTap: () async {
                                  await context.push('/chat/${chat.id}');
                                  if (context.mounted) {
                                    ref.invalidate(conversationsProvider);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
        ),
      ],
    );
  }
}

class _OnlineAvatar extends StatelessWidget {
  final String name;
  final String? path;
  final bool online;
  const _OnlineAvatar({required this.name, this.path, required this.online});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ProfileAvatar(name: name, path: path),
      if (online)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ],
  );
}
