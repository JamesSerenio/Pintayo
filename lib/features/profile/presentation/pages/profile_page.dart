import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../notifications/application/notification_controller.dart';
import '../../../location_sharing/application/sharing_controller.dart';
import '../../../settings/presentation/widgets/privacy_settings.dart';
import '../../../friends/presentation/pages/invite_page.dart';
import '../../data/profile_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(currentProfileProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(currentProfileProvider)),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: ProfileAvatar(
                name: profile?.displayName ?? '?',
                path: profile?.avatarPath,
                size: 96,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile?.displayName ?? 'Your profile',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('@${profile?.username ?? ''}', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => context.push('/profile/edit'),
              child: const Text('Edit profile'),
            ),
            TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const InviteCodeDialog(),
              ),
              icon: const Icon(Icons.qr_code),
              label: const Text('Your invite code'),
            ),
            const SizedBox(height: 24),
            const InfoCard(
              icon: Icons.shield_outlined,
              title: 'Private by default',
              body:
                  'You decide who can see you, and for how long. Chat works even when sharing is off.',
            ),
            const PrivacySettings(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => runAction(context, () async {
                await ref.read(sharingControllerProvider).change('stopped');
                await ref.read(notificationControllerProvider).unregister();
                await ref.read(authControllerProvider).logout();
                if (context.mounted) context.go('/auth');
              }),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      );
}
