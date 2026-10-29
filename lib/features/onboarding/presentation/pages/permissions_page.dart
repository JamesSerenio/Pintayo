import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../location_sharing/application/sharing_controller.dart';
import '../../../notifications/application/notification_controller.dart';
import '../../../../app/router/auth_redirect.dart';

class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('You’re in control')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Together, on your terms.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            const InfoCard(
              icon: Icons.location_on_outlined,
              title: 'Find yourself on the map',
              body:
                  'Location access centers your map. Sharing stays off until you select people and a duration. You can use chat without it.',
            ),
            FilledButton.tonal(
              onPressed: () => runAction(context, () async {
                await ref.read(locationTrackerProvider).enable();
                if (context.mounted) {
                  showNotice(
                    context,
                    'Location enabled. Sharing is still off.',
                  );
                }
              }),
              child: const Text('Enable Location'),
            ),
            const SizedBox(height: 24),
            const InfoCard(
              icon: Icons.notifications_none,
              title: 'Don’t miss a hello',
              body:
                  'Get notified about messages and friend requests. No alerts for every location update.',
            ),
            FilledButton.tonal(
              onPressed: () => runAction(context, () async {
                final granted = await ref
                    .read(notificationControllerProvider)
                    .requestPermission();
                if (context.mounted) {
                  showNotice(
                    context,
                    granted
                        ? 'Notifications enabled.'
                        : 'Notifications are unavailable or disabled. You can continue using PinTayo.',
                  );
                }
              }),
              child: const Text('Enable notifications'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go(
                returnLocation(
                  GoRouterState.of(context).uri.queryParameters['next'],
                ),
              ),
              child: const Text('Let’s go to the map'),
            ),
            TextButton(
              onPressed: () => context.go(
                returnLocation(
                  GoRouterState.of(context).uri.queryParameters['next'],
                ),
              ),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    ),
  );
}
