import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool mine;
  const MessageBubble({super.key, required this.message, required this.mine});
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mine ? AppColors.emerald : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.attachment != null)
            PrivateImage(bucket: 'attachments', path: message.attachment!),
          if (message.body?.isNotEmpty == true)
            Text(
              message.body!,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.navy,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context)}${mine ? ' · ${message.receipt.name}' : ''}',
            style: TextStyle(
              fontSize: 11,
              color: mine ? Colors.white : AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}
