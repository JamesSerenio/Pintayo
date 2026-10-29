import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/location_permission_action.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../notifications/application/notification_controller.dart';

class PrivacySettings extends ConsumerWidget {
  const PrivacySettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Hide activity status'),
          subtitle: const Text('Keep active now and last active private.'),
          value: profile?.hideActivity ?? true,
          onChanged: profile == null
              ? null
              : (hidden) => runAction(context, () async {
                  await ref
                      .read(profileRepositoryProvider)
                      .setActivityHidden(hidden);
                  ref.invalidate(currentProfileProvider);
                }),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('Enable notifications'),
          onTap: () => runAction(context, () async {
            final enabled = await ref
                .read(notificationControllerProvider)
                .requestPermission();
            if (context.mounted) {
              showNotice(
                context,
                enabled
                    ? 'Notifications enabled.'
                    : 'Notifications unavailable or disabled. Check device settings.',
              );
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Location permissions'),
          onTap: () => openLocationPermissions(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_off_outlined),
          title: const Text('Disable notifications on this device'),
          onTap: () => runAction(context, () async {
            await ref.read(notificationControllerProvider).unregister();
            if (context.mounted) {
              showNotice(context, 'Notifications disabled on this device.');
            }
          }),
        ),
        ExpansionTile(
          leading: const Icon(Icons.block),
          title: const Text('Blocked users'),
          children: [
            ListenableBuilder(
              listenable: ref.watch(notificationControllerProvider),
              builder: (_, _) => ListTile(
                title: const Text('Notifications'),
                subtitle: Text(
                  ref.read(notificationControllerProvider).statusText,
                ),
              ),
            ),
            ref
                .watch(blocksProvider)
                .when(
                  data: (users) => users.isEmpty
                      ? const ListTile(title: Text('No blocked users'))
                      : Column(
                          children: users
                              .map(
                                (id) => ListTile(
                                  title: Text(
                                    id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: TextButton(
                                    onPressed: () =>
                                        runAction(context, () async {
                                          await ref
                                              .read(friendsRepositoryProvider)
                                              .act(id, 'unblock');
                                          ref.invalidate(blocksProvider);
                                        }),
                                    child: const Text('Unblock'),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const ListTile(
                    title: Text('Couldn’t load blocked users.'),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
