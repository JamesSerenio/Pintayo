import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../data/circles_repository.dart';

final circlePeopleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(circlesRepositoryProvider).people(id),
    );

class CircleMembersDialog extends ConsumerWidget {
  final Circle circle;
  const CircleMembersDialog({super.key, required this.circle});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(supabaseProvider).auth.currentUser!.id;
    return AlertDialog(
      title: Text(circle.name),
      content: SizedBox(
        width: 360,
        height: 360,
        child: ref
            .watch(circlePeopleProvider(circle.id))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorView(
                onRetry: () => ref.invalidate(circlePeopleProvider(circle.id)),
              ),
              data: (people) => ListView(
                children: people
                    .map(
                      (p) => ListTile(
                        title: Text(p['display_name']),
                        subtitle: Text(
                          p['user_id'] == circle.owner
                              ? 'Owner'
                              : p['accepted']
                              ? 'Member'
                              : 'Invited',
                        ),
                        trailing: circle.owner != uid || p['user_id'] == uid
                            ? null
                            : IconButton(
                                tooltip: 'Remove member',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () => runAction(context, () async {
                                  await ref
                                      .read(circlesRepositoryProvider)
                                      .act(
                                        'remove_member',
                                        circle: circle.id,
                                        target: p['user_id'],
                                      );
                                  ref.invalidate(
                                    circlePeopleProvider(circle.id),
                                  );
                                }),
                              ),
                      ),
                    )
                    .toList(),
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
