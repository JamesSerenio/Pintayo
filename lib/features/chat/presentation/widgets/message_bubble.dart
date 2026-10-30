import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../data/models/message.dart';
import 'image_message.dart';
import 'quoted_message_preview.dart';
import 'message_action_sheet.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool mine, grouped, showAvatar;
  final String senderName;
  final String? senderAvatar, ownReaction;
  final Map<String, String> reactions;
  final Future<void> Function(String emoji)? onReact;
  final Future<void> Function()? onActions;
  final Message? replyTarget;
  final String replyName;
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.grouped = false,
    this.showAvatar = true,
    this.senderName = 'Friend',
    this.senderAvatar,
    this.reactions = const {},
    this.ownReaction,
    this.onReact,
    this.onActions,
    this.replyTarget,
    this.replyName = 'Reply',
  });
  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _details = false, _menuOpen = false;
  Future<void> _actions() async {
    if (_menuOpen || widget.message.deleted) return;
    _menuOpen = true;
    try {
      if (widget.onActions != null) {
        await widget.onActions!();
        return;
      }
      if (widget.onReact == null) return;
      final result = await showMessageActions(
        context,
        mine: widget.mine,
        selected: widget.ownReaction,
      );
      if (result?.emoji != null && mounted) {
        await runAction(context, () => widget.onReact!(result!.emoji!));
      }
    } finally {
      _menuOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final mine = widget.mine;
    final counts = <String, int>{};
    if (!message.deleted) {
      for (final emoji in widget.reactions.values) {
        counts.update(emoji, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final receipt = switch (message.receipt) {
      MessageReceipt.sent => 'Sent',
      MessageReceipt.delivered => 'Delivered',
      MessageReceipt.seen => 'Seen',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        widget.grouped ? 2 : 8,
        12,
        counts.isEmpty ? 2 : 6,
      ),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            SizedBox(
              width: 30,
              child: widget.showAvatar
                  ? ProfileAvatar(
                      name: widget.senderName,
                      path: widget.senderAvatar,
                      size: 30,
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.forwarded && !message.deleted)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Text(
                      '↪ Forwarded',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                if (message.replyTo != null && !message.deleted)
                  QuotedMessagePreview(
                    target: widget.replyTarget,
                    name: widget.replyName,
                  ),
                Semantics(
                  label: mine ? 'Your message' : '${widget.senderName} message',
                  hint:
                      'Tap for time and status. Long press or right click for actions.',
                  child: GestureDetector(
                    onTap: () => setState(() => _details = !_details),
                    onLongPress: message.deleted ? null : _actions,
                    onSecondaryTap: message.deleted ? null : _actions,
                    child: message.deleted
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              mine
                                  ? 'You deleted a message'
                                  : 'This message was deleted',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (message.attachment != null)
                                ImageMessage(path: message.attachment!),
                              if (message.body?.isNotEmpty == true)
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  margin: EdgeInsets.only(
                                    top: message.attachment == null ? 0 : 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? AppColors.emerald
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(
                                        !mine && widget.grouped ? 6 : 22,
                                      ),
                                      topRight: Radius.circular(
                                        mine && widget.grouped ? 6 : 22,
                                      ),
                                      bottomLeft: Radius.circular(
                                        mine ? 22 : 6,
                                      ),
                                      bottomRight: Radius.circular(
                                        mine ? 6 : 22,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    message.body!,
                                    style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : AppColors.navy,
                                      fontSize: 16,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                if (counts.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final entry in counts.entries)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _actions,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.ownReaction == entry.key
                                    ? AppColors.emerald
                                    : Colors.black12,
                              ),
                            ),
                            child: Text(
                              '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (_details)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 5,
                    ),
                    child: Text(
                      '${TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context)}${mine ? ' · $receipt' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
