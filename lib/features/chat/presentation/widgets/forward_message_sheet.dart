import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/chat_repository.dart';
import '../../data/message_actions_repository.dart';

class ForwardMessageSheet extends ConsumerStatefulWidget {
  final String message;
  const ForwardMessageSheet({super.key, required this.message});
  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  String _search = '';
  String? _selected, _error;
  bool _sending = false;
  final Map<String, String> _requests = {};
  Future<void> _send() async {
    if (_sending || _selected == null) return;
    final person = _selected!;
    final request = _requests.putIfAbsent(person, () => const Uuid().v4());
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final destination = await ref.read(chatRepositoryProvider).open(person);
      await ref
          .read(messageActionsRepositoryProvider)
          .forward(widget.message, destination, request);
      ref.invalidate(conversationsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Forward to',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close forwarding',
                    onPressed: _sending
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_sending,
                decoration: const InputDecoration(
                  hintText: 'Search friends',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
              ),
              Expanded(
                child: friends.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(friendsProvider),
                      child: const Text('Could not load friends. Retry'),
                    ),
                  ),
                  data: (all) {
                    final people = all
                        .where(
                          (f) =>
                              f.accepted &&
                              ('${f.person.displayName} ${f.person.username}')
                                  .toLowerCase()
                                  .contains(_search),
                        )
                        .toList();
                    if (people.isEmpty) {
                      return const Center(
                        child: Text('No eligible friends found.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (_, i) {
                        final p = people[i].person;
                        return ListTile(
                          leading: ProfileAvatar(
                            name: p.displayName,
                            path: p.avatarPath,
                          ),
                          title: Text(p.displayName),
                          subtitle: Text('@${p.username}'),
                          trailing: Icon(
                            _selected == p.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          selected: _selected == p.id,
                          onTap: _sending
                              ? null
                              : () => setState(() => _selected = p.id),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null || _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Forward'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
