import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/time_labels.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../location_sharing/data/models/shared_location.dart';
import '../../../location_sharing/application/sharing_controller.dart';
import '../../../profile/data/models/profile.dart';
import '../../../profile/data/profile_repository.dart';

final selectedPersonProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(profileRepositoryProvider).person(id),
);

class SelectedProfileSheet extends ConsumerWidget {
  final SharedLocation location;
  final Profile? person;
  const SelectedProfileSheet({
    super.key,
    required this.location,
    required this.person,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(selectedPersonProvider(location.owner)).asData?.value ??
        person;
    final own = ref.read(locationTrackerProvider).position;
    final distance = own == null
        ? null
        : Geolocator.distanceBetween(
            own.latitude,
            own.longitude,
            location.latitude,
            location.longitude,
          );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              name: current?.displayName ?? '?',
              path: current?.avatarPath,
              size: 76,
            ),
            const SizedBox(height: 12),
            Text(
              current?.displayName ?? 'Circle member',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              current?.hideActivity == false
                  ? 'Last active ${timeAgo(current?.lastActive)}'
                  : 'Activity hidden',
            ),
            const SizedBox(height: 20),
            InfoCard(
              icon: Icons.location_on_outlined,
              title:
                  '${location.fresh ? 'Location updated' : 'Last known location'} ${timeAgo(location.fixedAt)}',
              body:
                  'Fix: ${location.fixedAt.toLocal()}\nAccuracy ±${location.accuracy.round()} m${distance == null ? '' : '\nStraight-line distance: ${(distance / 1000).toStringAsFixed(2)} km'}',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => runAction(context, () async {
                final id = await ref
                    .read(chatRepositoryProvider)
                    .open(location.owner);
                if (context.mounted) {
                  Navigator.pop(context);
                  context.push('/chat/$id');
                }
              }),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message'),
            ),
          ],
        ),
      ),
    );
  }
}
