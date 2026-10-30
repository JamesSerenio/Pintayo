import 'package:flutter/material.dart';
import 'message_reaction_bar.dart';

enum MessageAction { copy, forward, reply, delete, hide }

class MessageActionChoice {
  final MessageAction? action;
  final String? emoji;
  const MessageActionChoice.action(this.action) : emoji = null;
  const MessageActionChoice.reaction(this.emoji) : action = null;
}

Future<MessageActionChoice?> showMessageActions(
  BuildContext context, {
  required bool mine,
  String? selected,
}) => showModalBottomSheet<MessageActionChoice>(
  context: context,
  showDragHandle: true,
  sheetAnimationStyle: AnimationStyle.noAnimation,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MessageReactionBar(
              selected: selected,
              onSelected: (emoji) =>
                  Navigator.pop(context, MessageActionChoice.reaction(emoji)),
            ),
          ),
          const Divider(height: 1),
          for (final item in [
            (Icons.copy_outlined, 'Copy', MessageAction.copy),
            (Icons.forward, 'Forward', MessageAction.forward),
            (Icons.reply, 'Reply', MessageAction.reply),
            (
              Icons.delete_outline,
              mine ? 'Delete' : 'Delete for me',
              mine ? MessageAction.delete : MessageAction.hide,
            ),
          ])
            ListTile(
              leading: Icon(item.$1),
              title: Text(item.$2),
              onTap: () =>
                  Navigator.pop(context, MessageActionChoice.action(item.$3)),
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    ),
  ),
);
