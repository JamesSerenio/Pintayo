import 'package:flutter/material.dart';

Future<bool> confirmMessageDeletion(
  BuildContext context, {
  required bool everyone,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
          everyone
              ? 'Delete this message for everyone in this conversation?'
              : 'Remove this message only for you? The other person will still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ??
    false;
