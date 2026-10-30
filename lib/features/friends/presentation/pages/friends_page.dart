import '../../application/request_attention.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../circles/presentation/pages/circles_page.dart';
import '../../data/friends_repository.dart';
import '../../../profile/data/models/profile.dart';
import 'invite_page.dart';

class FriendsPage extends ConsumerStatefulWidget {
  final int initialTab;
  const FriendsPage({super.key, this.initialTab = 0});
  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabs.addListener(_viewRequests);
    if (widget.initialTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _viewRequests());
    }
  }

  void _viewRequests() {
    if (!mounted || _tabs.index != 1) return;
    final ids = (ref.read(friendsProvider).asData?.value ?? [])
        .where((f) => f.incoming && !f.accepted)
        .map((f) => f.id);
    ref.read(requestAttentionProvider).mark('requests', ids);
    ref.read(requestAttentionProvider).mark('friends', ids);
  }

  final _search = TextEditingController();
  List<Profile>? _results;
  bool _searching = false;
  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _act(String id, String action) => runAction(context, () async {
    await ref.read(friendsRepositoryProvider).act(id, action);
    ref.invalidate(friendsProvider);
    ref.invalidate(blocksProvider);
    if (mounted) setState(() => _results = null);
  });
  Widget _person(Profile person, {Friendship? friendship}) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ProfileAvatar(name: person.displayName, path: person.avatarPath),
      title: Text(person.displayName),
      subtitle: Text('@${person.username}'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Friend options',
        onSelected: (action) async {
          if (action == 'message') {
            await runAction(context, () async {
              final id = await ref.read(chatRepositoryProvider).open(person.id);
              if (mounted) context.push('/chat/$id');
            });
          } else {
            await _act(person.id, action);
          }
        },
        itemBuilder: (_) => [
          if (friendship == null)
            const PopupMenuItem(value: 'request', child: Text('Send request')),
          if (friendship?.accepted == true) ...[
            const PopupMenuItem(value: 'message', child: Text('Message')),
            const PopupMenuItem(value: 'remove', child: Text('Remove friend')),
          ] else if (friendship != null) ...[
            if (friendship.incoming) ...[
              const PopupMenuItem(
                value: 'accept',
                child: Text('Accept request'),
              ),
              const PopupMenuItem(value: 'decline', child: Text('Decline')),
            ] else
              const PopupMenuItem(
                value: 'cancel',
                child: Text('Cancel request'),
              ),
          ],
          const PopupMenuItem(value: 'block', child: Text('Block user')),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    ref.listen(friendsProvider, (_, next) {
      if (next.hasValue) _viewRequests();
    });
    final friends = ref.watch(friendsProvider);
    final requests = (friends.asData?.value ?? [])
        .where((f) => f.incoming && !f.accepted)
        .map((f) => f.id)
        .toList();
    final attention = ref.watch(requestAttentionProvider);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your people',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Invite friends',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const InviteCodeDialog(),
                  ),
                  icon: const Icon(Icons.qr_code_rounded),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: attention,
            builder: (_, _) => TabBar(
              controller: _tabs,
              onTap: (index) {
                if (index == 1) attention.mark('requests', requests);
              },
              tabs: [
                const Tab(text: 'Friends'),
                Tab(
                  child: Badge(
                    isLabelVisible: attention.count('requests', requests) > 0,
                    label: Text('${attention.count('requests', requests)}'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Requests'),
                    ),
                  ),
                ),
                const Tab(text: 'Circles'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Username or user ID',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Search',
                            icon: _searching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward),
                            onPressed: _searching
                                ? null
                                : () async {
                                    setState(() => _searching = true);
                                    await runAction(context, () async {
                                      final result = await ref
                                          .read(friendsRepositoryProvider)
                                          .search(_search.text);
                                      if (mounted) {
                                        setState(() => _results = result);
                                      }
                                    });
                                    if (mounted) {
                                      setState(() => _searching = false);
                                    }
                                  },
                          ),
                        ),
                        onSubmitted: (_) async {
                          await runAction(context, () async {
                            final result = await ref
                                .read(friendsRepositoryProvider)
                                .search(_search.text);
                            if (mounted) setState(() => _results = result);
                          });
                        },
                      ),
                    ),
                    if (_results != null)
                      TextButton(
                        onPressed: () => setState(() => _results = null),
                        child: const Text('Back to friends'),
                      ),
                    Expanded(
                      child: _results != null
                          ? _results!.isEmpty
                                ? const EmptyView(
                                    title: 'No matches yet',
                                    description:
                                        'Try at least three characters or an exact user ID.',
                                  )
                                : ListView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    children: _results!
                                        .map((p) => _person(p))
                                        .toList(),
                                  )
                          : friends.when(
                              data: (list) {
                                final accepted = list
                                    .where((f) => f.accepted)
                                    .toList();
                                if (accepted.isEmpty) {
                                  return const EmptyView(
                                    title: 'Good things start with hello',
                                    description:
                                        'Find a friend or share your invite code. Sharing stays off until you choose.',
                                  );
                                }
                                return RefreshIndicator(
                                  onRefresh: () async =>
                                      ref.refresh(friendsProvider.future),
                                  child: ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: accepted
                                        .map(
                                          (f) =>
                                              _person(f.person, friendship: f),
                                        )
                                        .toList(),
                                  ),
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (_, _) => ErrorView(
                                onRetry: () => ref.invalidate(friendsProvider),
                              ),
                            ),
                    ),
                  ],
                ),
                friends.when(
                  data: (list) {
                    final pending = list.where((f) => !f.accepted).toList();
                    if (pending.isEmpty) {
                      return const EmptyView(
                        icon: Icons.mark_email_read_outlined,
                        title: 'All caught up',
                        description: 'New friend requests will appear here.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.refresh(friendsProvider.future),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: pending
                            .map(
                              (f) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.incoming
                                        ? 'Wants to connect'
                                        : 'Request sent',
                                  ),
                                  _person(f.person, friendship: f),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      ErrorView(onRetry: () => ref.invalidate(friendsProvider)),
                ),
                const CirclesPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
