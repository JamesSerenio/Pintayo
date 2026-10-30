import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../../shared/widgets/photo_viewer.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../application/message_reactions.dart';
import '../../data/models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool mine, grouped, showAvatar;
  final String senderName;
  final String? senderAvatar, ownReaction;
  final Map<String, String> reactions;
  final Future<void> Function(String emoji)? onReact;
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
  });
  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _details = false;
  Future<void> _pickReaction() async {
    if (widget.onReact == null) return;
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'React to message',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  for (final emoji in reactionEmojis)
                    Semantics(
                      selected: widget.ownReaction == emoji,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: widget.ownReaction == emoji
                              ? AppColors.emerald.withValues(alpha: 0.12)
                              : null,
                        ),
                        onPressed: () => Navigator.pop(context, emoji),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.ownReaction != null)
                const Text('Tap your reaction again to remove it.'),
            ],
          ),
        ),
      ),
    );
    if (emoji != null && mounted) {
      await runAction(context, () => widget.onReact!(emoji));
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final mine = widget.mine;
    final counts = <String, int>{};
    for (final emoji in widget.reactions.values) {
      counts.update(emoji, (n) => n + 1, ifAbsent: () => 1);
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
                Semantics(
                  label: mine ? 'Your message' : '${widget.senderName} message',
                  hint: 'Tap for time and status. Long press to react.',
                  child: GestureDetector(
                    onTap: () => setState(() => _details = !_details),
                    onLongPress: widget.onReact == null ? null : _pickReaction,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: EdgeInsets.all(
                        message.attachment == null ? 12 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.emerald : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(
                            !mine && widget.grouped ? 6 : 22,
                          ),
                          topRight: Radius.circular(
                            mine && widget.grouped ? 6 : 22,
                          ),
                          bottomLeft: Radius.circular(mine ? 22 : 6),
                          bottomRight: Radius.circular(mine ? 6 : 22),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.attachment != null)
                            Semantics(
                              button: true,
                              label: 'Open photo',
                              child: GestureDetector(
                                onTap: () => openPhotoViewer(
                                  context,
                                  bucket: 'attachments',
                                  path: message.attachment!,
                                ),
                                child: PrivateImage(
                                  bucket: 'attachments',
                                  path: message.attachment!,
                                ),
                              ),
                            ),
                          if (message.body?.isNotEmpty == true)
                            Padding(
                              padding: message.attachment == null
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.all(8),
                              child: Text(
                                message.body!,
                                style: TextStyle(
                                  color: mine ? Colors.white : AppColors.navy,
                                  fontSize: 16,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          if (message.attachment != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'Photo message details',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.more_horiz,
                                  size: 20,
                                  color: mine ? Colors.white : AppColors.muted,
                                ),
                                onPressed: () =>
                                    setState(() => _details = !_details),
                              ),
                            ),
                        ],
                      ),
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
                          onTap: _pickReaction,
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
