import 'package:flutter/material.dart';
import '../../data/models/message.dart';

class QuotedMessagePreview extends StatelessWidget {
  final Message? target;
  final String name;
  const QuotedMessagePreview({super.key, this.target, required this.name});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 280),
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      border: const Border(left: BorderSide(color: Colors.black26, width: 3)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        Text(
          target == null
              ? 'Message unavailable'
              : target!.deleted
              ? 'Message removed'
              : target!.body ?? 'Photo',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
