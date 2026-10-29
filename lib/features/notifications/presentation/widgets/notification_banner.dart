import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../application/notification_controller.dart';

class NotificationBanner extends ConsumerWidget {
  final Widget child;
  const NotificationBanner({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(configProvider).isConfigured) return child;
    final controller = ref.watch(notificationControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) => Column(
        children: [
          if (controller.foreground != null)
            SafeArea(
              bottom: false,
              child: MaterialBanner(
                leading: const Icon(Icons.notifications_outlined),
                content: Text(
                  controller.foreground!.route.startsWith('/chat/')
                      ? 'You have a new message.'
                      : 'You have a new friend request.',
                ),
                actions: [
                  TextButton(
                    onPressed: controller.dismissForeground,
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: controller.openForeground,
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
