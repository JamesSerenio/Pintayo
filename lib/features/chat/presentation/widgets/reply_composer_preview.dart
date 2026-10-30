import 'package:flutter/material.dart';
import '../../data/models/message.dart';

class ReplyComposerPreview extends StatelessWidget {
  final Message message;
  final String name;
  final VoidCallback onCancel;
  const ReplyComposerPreview({
    super.key,
    required this.message,
    required this.name,
    required this.onCancel,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: const Icon(Icons.reply),
    title: Text('Replying to $name'),
    subtitle: Text(
      message.deleted ? 'Message removed' : message.body ?? 'Photo',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: IconButton(
      tooltip: 'Cancel reply',
      onPressed: onCancel,
      icon: const Icon(Icons.close),
    ),
  );
}
