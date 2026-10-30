import '../../application/message_reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../presence/application/conversation_presence.dart';
import '../../application/chat_controller.dart';
import '../../data/chat_repository.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';

class ConversationPage extends ConsumerStatefulWidget {
  final String conversationId;
  const ConversationPage({super.key, required this.conversationId});
  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(chatControllerProvider(widget.conversationId))
        .setActive(state == AppLifecycleState.resumed);
    ref
        .read(conversationPresenceProvider(widget.conversationId))
        .setActive(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(chatControllerProvider(widget.conversationId));
    final reactions = ref.watch(
      messageReactionsProvider(widget.conversationId),
    );
    final presence = ref.watch(
      conversationPresenceProvider(widget.conversationId),
    );
    final partner = ref
        .watch(chatPartnerProvider(widget.conversationId))
        .asData
        ?.value;
    final online = ref.watch(connectivityProvider).asData?.value ?? false;
    final user = ref.watch(chatRepositoryProvider).userId;
    final chat = Column(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, reactions]),
            builder: (_, _) {
              if (controller.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  if (controller.error != null)
                    MaterialBanner(
                      content: Text(controller.error!),
                      actions: [
                        TextButton(
                          onPressed: controller.catchUp,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  Expanded(
                    child:
                        controller.messages.isEmpty && controller.failed.isEmpty
                        ? const EmptyView(
                            icon: Icons.chat_bubble_outline,
                            title: 'Start with kumusta',
                            description:
                                'Messages stay here, even when your friend is away.',
                          )
                        : ListView(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            children: [
                              ...controller.failed.reversed.map(
                                (failed) => ListTile(
                                  title: Text(failed.text ?? 'Photo'),
                                  subtitle: const Text(
                                    'Not confirmed · tap to retry',
                                  ),
                                  trailing: const Icon(Icons.refresh),
                                  onTap: online
                                      ? () => controller.send(retry: failed)
                                      : null,
                                ),
                              ),
                              for (
                                var i = controller.messages.length - 1;
                                i >= 0;
                                i--
                              )
                                MessageBubble(
                                  key: ValueKey(controller.messages[i].id),
                                  message: controller.messages[i],
                                  mine: controller.messages[i].sender == user,
                                  senderName: partner?.displayName ?? 'Friend',
                                  senderAvatar: partner?.avatarPath,
                                  grouped:
                                      i > 0 &&
                                      controller.messages[i - 1].sender ==
                                          controller.messages[i].sender &&
                                      controller.messages[i].createdAt
                                              .difference(
                                                controller
                                                    .messages[i - 1]
                                                    .createdAt,
                                              )
                                              .inMinutes <
                                          2,
                                  showAvatar:
                                      i == controller.messages.length - 1 ||
                                      controller.messages[i + 1].sender !=
                                          controller.messages[i].sender ||
                                      controller.messages[i + 1].createdAt
                                              .difference(
                                                controller
                                                    .messages[i]
                                                    .createdAt,
                                              )
                                              .inMinutes >=
                                          2,
                                  reactions:
                                      reactions.values[controller
                                          .messages[i]
                                          .id] ??
                                      const {},
                                  ownReaction: reactions
                                      .values[controller.messages[i].id]?[user],
                                  onReact: online
                                      ? (emoji) => reactions.react(
                                          controller.messages[i].id,
                                          emoji,
                                        )
                                      : null,
                                ),
                              if (controller.hasOlder)
                                Center(
                                  child: TextButton(
                                    onPressed: controller.older,
                                    child: const Text('Load earlier messages'),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => MessageComposer(
            enabled: online,
            sending: controller.sending,
            onSend: (text) => controller.send(text: text),
            onPhoto: () => controller.send(photo: true),
            onChanged: presence.changedText,
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: presence,
          builder: (_, _) => Row(
            children: [
              ProfileAvatar(
                name: partner?.displayName ?? '?',
                path: partner?.avatarPath,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner?.displayName ?? 'Conversation',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      presence.typing ? 'Typing…' : presence.status,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (_, constraints) =>
            constraints.maxWidth >= AppSpacing.tabletBreakpoint
            ? Row(
                children: [
                  const Expanded(child: MapPage()),
                  SizedBox(width: 420, child: chat),
                ],
              )
            : chat,
      ),
    );
  }
}
