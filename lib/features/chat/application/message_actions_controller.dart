import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/feedback_views.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/message_copy_service.dart';
import '../data/message_actions_repository.dart';
import '../data/models/message.dart';
import '../presentation/widgets/message_action_sheet.dart';
import '../presentation/widgets/delete_message_sheet.dart';
import '../presentation/widgets/delete_message_dialog.dart';
import '../presentation/widgets/forward_message_sheet.dart';
import 'chat_controller.dart';
import 'message_reactions.dart';
import '../data/chat_repository.dart';

class MessageActionsController {
  bool _open = false;
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    Message message,
    bool mine,
  ) async {
    if (_open || message.deleted) return;
    _open = true;
    FocusScope.of(context).unfocus();
    try {
      final reactions = ref.read(
        messageReactionsProvider(message.conversationId),
      );
      final user = ref.read(supabaseProvider).auth.currentUser!.id;
      final choice = await showMessageActions(
        context,
        mine: mine,
        selected: reactions.values[message.id]?[user],
      );
      if (!context.mounted || choice == null) return;
      if (choice.emoji != null) {
        await runAction(
          context,
          () => reactions.react(message.id, choice.emoji!),
        );
        return;
      }
      switch (choice.action) {
        case MessageAction.copy:
          await runAction(context, () async {
            final notice = await copyMessage(
              message,
              ref.read(supabaseProvider),
            );
            if (context.mounted) showNotice(context, notice);
          });
        case MessageAction.forward:
          final sent = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            isDismissible: false,
            enableDrag: false,
            builder: (_) => ForwardMessageSheet(message: message.id),
          );
          if (sent == true && context.mounted) {
            showNotice(context, 'Message forwarded.');
          }
        case MessageAction.reply:
          ref
              .read(chatControllerProvider(message.conversationId))
              .reply(message);
        case MessageAction.hide:
          await _delete(context, ref, message, false);
        case MessageAction.delete:
          final everyone = await chooseDeleteScope(context);
          if (everyone != null && context.mounted) {
            await _delete(context, ref, message, everyone);
          }
        case null:
          break;
      }
    } finally {
      _open = false;
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Message message,
    bool everyone,
  ) async {
    if (!await confirmMessageDeletion(context, everyone: everyone) ||
        !context.mounted) {
      return;
    }
    await runAction(context, () async {
      final actions = ref.read(messageActionsRepositoryProvider);
      if (everyone) {
        await actions.deleteEveryone(message.id);
      } else {
        await actions.hide(message.id);
      }
      await ref.read(chatControllerProvider(message.conversationId)).catchUp();
      await ref
          .read(messageReactionsProvider(message.conversationId))
          .refresh();
      ref.invalidate(conversationsProvider);
    });
  }
}

final messageActionsControllerProvider = Provider.autoDispose
    .family<MessageActionsController, String>(
      (ref, id) => MessageActionsController(),
    );
