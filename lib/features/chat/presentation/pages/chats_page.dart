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
  Widget build(BuildContext context, WidgetRef ref) => Column(
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
                              leading: ProfileAvatar(
                                name: chat.friend?.displayName ?? '?',
                                path: chat.friend?.avatarPath,
                              ),
                              title: Text(
                                chat.friend?.displayName ?? 'PinTayo member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                chat.preview,
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
                              onTap: () => context.push('/chat/${chat.id}'),
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
