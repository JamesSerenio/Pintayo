import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/circles_repository.dart';
import '../widgets/circle_members_dialog.dart';

class CirclesPage extends ConsumerWidget {
  const CirclesPage({super.key});
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('A circle of your own'),
        content: TextField(
          controller: controller,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Circle name',
            hintText: 'Family, Barkada, Workmates…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    await runAction(context, () async {
      await ref.read(circlesRepositoryProvider).act('create', title: name);
      ref.invalidate(circlesProvider);
    });
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    Circle circle,
  ) async {
    await runAction(context, () async {
      final friends = (await ref.read(
        friendsProvider.future,
      )).where((f) => f.accepted).toList();
      if (!context.mounted) return;
      final id = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text('Invite to ${circle.name}'),
          children: [
            if (friends.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Connect with a friend first.'),
              ),
            ...friends.map(
              (f) => SimpleDialogOption(
                onPressed: () => Navigator.pop(c, f.person.id),
                child: Text(f.person.displayName),
              ),
            ),
          ],
        ),
      );
      if (id != null) {
        await ref
            .read(circlesRepositoryProvider)
            .act('invite', circle: circle.id, target: id);
      }
      if (context.mounted && id != null) {
        showNotice(context, 'Circle invitation sent.');
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(circlesProvider);
    final uid = ref.watch(supabaseProvider).auth.currentUser!.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.tonalIcon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create a circle'),
          ),
        ),
        Expanded(
          child: circles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                ErrorView(onRetry: () => ref.invalidate(circlesProvider)),
            data: (items) => items.isEmpty
                ? const EmptyView(
                    icon: Icons.groups_outlined,
                    title: 'Your everyday circles',
                    description:
                        'Keep family, barkada, and workmates close. Membership never starts location sharing.',
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.refresh(circlesProvider.future),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: items
                          .map(
                            (circle) => Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.groups_outlined),
                                ),
                                title: Text(circle.name),
                                onTap: circle.accepted
                                    ? () => showDialog(
                                        context: context,
                                        builder: (_) =>
                                            CircleMembersDialog(circle: circle),
                                      )
                                    : null,
                                subtitle: Text(
                                  !circle.accepted
                                      ? 'You’re invited'
                                      : circle.owner == uid
                                      ? 'You own this circle'
                                      : 'Member',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'invite') {
                                      _invite(context, ref, circle);
                                      return;
                                    }
                                    runAction(context, () async {
                                      await ref
                                          .read(circlesRepositoryProvider)
                                          .act(action, circle: circle.id);
                                      ref.invalidate(circlesProvider);
                                    });
                                  },
                                  itemBuilder: (_) => [
                                    if (!circle.accepted)
                                      const PopupMenuItem(
                                        value: 'accept',
                                        child: Text('Accept invitation'),
                                      ),
                                    if (circle.owner == uid)
                                      const PopupMenuItem(
                                        value: 'invite',
                                        child: Text('Invite a friend'),
                                      ),
                                    PopupMenuItem(
                                      value: 'leave',
                                      child: Text(
                                        circle.owner == uid
                                            ? 'Delete circle'
                                            : circle.accepted
                                            ? 'Leave circle'
                                            : 'Decline invitation',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
