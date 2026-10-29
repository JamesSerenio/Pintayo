import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../circles/data/circles_repository.dart';
import '../../data/meetups_repository.dart';

class MeetupPanel extends ConsumerStatefulWidget {
  final LatLng point;
  const MeetupPanel({super.key, required this.point});
  @override
  ConsumerState<MeetupPanel> createState() => _MeetupPanelState();
}

class _MeetupPanelState extends ConsumerState<MeetupPanel> {
  final _title = TextEditingController();
  final Set<String> _guests = {};
  String? _circle;
  bool _busy = false;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends =
        ref
            .watch(friendsProvider)
            .asData
            ?.value
            .where((f) => f.accepted)
            .toList() ??
        [];
    final circles =
        ref
            .watch(circlesProvider)
            .asData
            ?.value
            .where((c) => c.accepted)
            .toList() ??
        [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let’s meet here',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Meet-up name',
                  hintText: 'Kape tayo?',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: '',
                decoration: const InputDecoration(labelText: 'Invite a circle'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Choose individual friends'),
                  ),
                  ...circles.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (id) =>
                    setState(() => _circle = id == '' ? null : id),
              ),
              Expanded(
                child: ListView(
                  children: friends
                      .map(
                        (f) => CheckboxListTile(
                          title: Text(f.person.displayName),
                          value: _guests.contains(f.person.id),
                          onChanged: (value) => setState(() {
                            value!
                                ? _guests.add(f.person.id)
                                : _guests.remove(f.person.id);
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Text(
                'Pin stays available for 24 hours. No arrival estimates or road routing.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (_title.text.trim().isEmpty ||
                            (_guests.isEmpty && _circle == null)) {
                          showNotice(
                            context,
                            'Add a name and choose your people.',
                          );
                          return;
                        }
                        setState(() => _busy = true);
                        await runAction(context, () async {
                          await ref
                              .read(meetupsRepositoryProvider)
                              .create(
                                _title.text.trim(),
                                widget.point.latitude,
                                widget.point.longitude,
                                _guests.toList(),
                                _circle,
                              );
                          ref.invalidate(meetupsProvider);
                          if (context.mounted) Navigator.pop(context);
                        });
                        if (mounted) setState(() => _busy = false);
                      },
                child: Text(_busy ? 'Creating…' : 'Create meet-up pin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MeetupDetails extends ConsumerWidget {
  final Meetup meetup;
  const MeetupDetails({super.key, required this.meetup});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_circle, size: 48),
          const SizedBox(height: 12),
          Text(meetup.title, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            '${meetup.latitude.toStringAsFixed(5)}, ${meetup.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 12),
          Text('Available until ${meetup.expiresAt.toLocal()}'),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ref
                .watch(meetupPeopleProvider(meetup.id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Text('Participant status is unavailable.'),
                  data: (people) => ListView(
                    children: people
                        .map(
                          (p) => ListTile(
                            title: Text(p['display_name']),
                            trailing: Text(p['status'] ?? 'Invited'),
                          ),
                        )
                        .toList(),
                  ),
                ),
          ),
          Wrap(
            spacing: 8,
            children: ['Papunta na', 'Nandito na']
                .map(
                  (status) => ActionChip(
                    label: Text(status),
                    onPressed: () => runAction(context, () async {
                      await ref
                          .read(meetupsRepositoryProvider)
                          .status(meetup.id, status);
                      ref.invalidate(meetupPeopleProvider(meetup.id));
                      if (context.mounted) {
                        showNotice(context, 'Status updated: $status');
                      }
                    }),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}
