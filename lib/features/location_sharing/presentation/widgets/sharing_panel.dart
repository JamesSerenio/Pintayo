import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../circles/data/circles_repository.dart';
import '../../application/sharing_controller.dart';

class SharingPanel extends ConsumerStatefulWidget {
  const SharingPanel({super.key});
  @override
  ConsumerState<SharingPanel> createState() => _SharingPanelState();
}

class _SharingPanelState extends ConsumerState<SharingPanel> {
  final Set<String> _friends = {}, _circles = {};
  int _minutes = 15;
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final circles = ref.watch(circlesProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share a little of your day',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only your selected people can see your location. You can pause or stop anytime.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'FRIENDS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    friends.when(
                      data: (items) => Column(
                        children: items
                            .where((f) => f.accepted)
                            .map(
                              (f) => CheckboxListTile(
                                title: Text(f.person.displayName),
                                value: _friends.contains(f.person.id),
                                onChanged: (v) => setState(() {
                                  v!
                                      ? _friends.add(f.person.id)
                                      : _friends.remove(f.person.id);
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Couldn’t load friends.'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CIRCLES',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    circles.when(
                      data: (items) => Column(
                        children: items
                            .where((c) => c.accepted)
                            .map(
                              (c) => CheckboxListTile(
                                title: Text(c.name),
                                value: _circles.contains(c.id),
                                onChanged: (v) => setState(() {
                                  v!
                                      ? _circles.add(c.id)
                                      : _circles.remove(c.id);
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Couldn’t load circles.'),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [(15, '15 min'), (60, '1 hour'), (0, 'Until stopped')]
                    .map(
                      (choice) => ChoiceChip(
                        label: Text(choice.$2),
                        selected: _minutes == choice.$1,
                        onSelected: (_) => setState(() => _minutes = choice.$1),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || (_friends.isEmpty && _circles.isEmpty)
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await runAction(context, () async {
                            await ref
                                .read(sharingControllerProvider)
                                .start(
                                  _friends.toList(),
                                  _circles.toList(),
                                  _minutes,
                                );
                            if (context.mounted) Navigator.pop(context);
                          });
                          if (mounted) setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.share_location),
                  label: Text(
                    _busy ? 'Starting…' : 'Enable Location & Start Sharing',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
