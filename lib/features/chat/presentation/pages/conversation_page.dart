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
        ListenableBuilder(
          listenable: presence,
          builder: (_, _) => ListTile(
            leading: ProfileAvatar(
              name: partner?.displayName ?? '?',
              path: partner?.avatarPath,
            ),
            title: Text(partner?.displayName ?? 'Conversation'),
            subtitle: Text(presence.typing ? 'Typing…' : presence.status),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: controller,
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
                              ...controller.messages.reversed.map(
                                (message) => MessageBubble(
                                  message: message,
                                  mine: message.sender == user,
                                ),
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
      appBar: AppBar(title: const Text('A little closer')),
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
