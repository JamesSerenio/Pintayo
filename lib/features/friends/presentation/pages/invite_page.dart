import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../data/friends_repository.dart';

class InviteCodeDialog extends ConsumerWidget {
  const InviteCodeDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(supabaseProvider).auth.currentUser!.id;
    final link = '${ref.watch(configProvider).inviteBase}/invite/$id';
    return AlertDialog(
      title: const Text('Bring your people along'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: link, size: 220),
            const SizedBox(height: 12),
            const Text(
              'Scan with your camera or share this link. Connecting never starts location sharing.',
            ),
            const SizedBox(height: 12),
            SelectableText(id, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text: 'Magkita sa mapa. Join me on PinTayo: $link',
              sharePositionOrigin: Rect.fromLTWH(
                0,
                0,
                MediaQuery.sizeOf(context).width,
                1,
              ),
            ),
          ),
          child: const Text('Share invite'),
        ),
      ],
    );
  }
}

class InvitePage extends ConsumerWidget {
  final String userId;
  const InvitePage({super.key, required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Connect on PinTayo')),
    body: EmptyView(
      icon: Icons.waving_hand_outlined,
      title: 'Say hello',
      description:
          'Send a friend request to this PinTayo member. You’ll choose separately whether to share your location.',
      action: FilledButton(
        onPressed: () => runAction(context, () async {
          await ref.read(friendsRepositoryProvider).act(userId, 'request');
          ref.invalidate(friendsProvider);
          if (context.mounted) context.go('/friends');
        }),
        child: const Text('Send friend request'),
      ),
    ),
  );
}
