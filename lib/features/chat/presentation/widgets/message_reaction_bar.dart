import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/message_reactions.dart';

class MessageReactionBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  const MessageReactionBar({
    super.key,
    this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final emoji in reactionEmojis)
        Expanded(
          child: Semantics(
            selected: selected == emoji,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 48),
                padding: EdgeInsets.zero,
                backgroundColor: selected == emoji
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : null,
              ),
              onPressed: () => onSelected(emoji),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
        ),
    ],
  );
}
