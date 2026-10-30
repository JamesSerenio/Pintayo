import 'package:flutter/material.dart';

Future<bool?> chooseDeleteScope(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      useSafeArea: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete for me'),
            onTap: () => Navigator.pop(context, false),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Delete for everyone'),
            onTap: () => Navigator.pop(context, true),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
        ],
      ),
    );
