import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/supabase_provider.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/data/models/message.dart';
import '../../features/friends/data/friends_repository.dart';
import '../../features/location_sharing/application/sharing_controller.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/presence/application/app_presence_controller.dart';
import '../../features/presence/application/conversation_presence.dart';
import '../../features/chat/application/chat_controller.dart';
import '../../features/circles/data/circles_repository.dart';
import '../../features/meetups/data/meetups_repository.dart';
import '../../features/map/application/map_controller.dart';

/// User-scoped lifecycle. Never marks a push acceptance as delivery. Only an
/// authenticated application receiving/querying messages acknowledges them.
class SessionServices extends ConsumerStatefulWidget {
  final Widget child;
  const SessionServices({super.key, required this.child});
  @override
  ConsumerState<SessionServices> createState() => _SessionServicesState();
}

class _SessionServicesState extends ConsumerState<SessionServices>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  String? _user;
  bool _active = true;
  AuthController? _auth;
  SupabaseClient? _client;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(configProvider).isConfigured) {
      _client = ref.read(supabaseProvider);
      _auth = ref.read(authControllerProvider);
      _auth!.addListener(_authChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _authChanged());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_authChanged);
    if (_channel != null) _client?.removeChannel(_channel!);
    super.dispose();
  }

  void _authChanged() {
    if (!mounted) return;
    final uid = _auth?.userId;
    if (uid == _user) return;
    if (_channel != null) _client?.removeChannel(_channel!);
    _channel = null;
    ref.invalidate(currentProfileProvider);
    ref.invalidate(friendsProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(sharingControllerProvider);
    ref.invalidate(locationTrackerProvider);
    ref.invalidate(appPresenceProvider);
    ref.invalidate(conversationPresenceProvider);
    ref.invalidate(chatControllerProvider);
    ref.invalidate(chatPartnerProvider);
    ref.invalidate(circlesProvider);
    ref.invalidate(blocksProvider);
    ref.invalidate(meetupsProvider);
    ref.invalidate(mapStateProvider);
    setState(() => _user = uid);
    if (uid != null) _connect(uid);
  }

  Future<void> _catchUp() async {
    if (!_active || _user == null) return;
    try {
      final repository = ref.read(chatRepositoryProvider);
      final chats = await repository.conversations();
      for (final chat in chats) {
        if (chat.unread > 0) {
          // Query the messages before acknowledging receipt by this app.
          final received = await repository.page(chat.id);
          await repository.acknowledge(
            chat.id,
            ids: received.map((m) => m.id).toList(),
          );
        }
      }
      await repository.client.rpc('activity');
      ref.invalidate(conversationsProvider);
    } catch (_) {
      /* Next resume/reconnect retries from durable state. */
    }
  }

  void _connect(String uid) {
    final client = ref.read(supabaseProvider);
    if (_channel != null) client.removeChannel(_channel!);
    _user = uid;
    _channel =
        client
            .channel('inbox:$uid')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              callback: (event) async {
                if (!_active || event.newRecord.isEmpty) return;
                final message = Message.fromJson(event.newRecord);
                if (message.sender != uid) {
                  try {
                    await ref
                        .read(chatRepositoryProvider)
                        .acknowledge(message.conversationId, ids: [message.id]);
                  } catch (_) {
                    /* Reconnect retries. */
                  }
                }
                ref.invalidate(conversationsProvider);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'friendships',
              callback: (_) => ref.invalidate(friendsProvider),
            )
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) _catchUp();
          });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_user != null) ref.read(appPresenceProvider).setActive(_active);
    if (_active) {
      _catchUp();
    } else if (_user != null) {
      ref.read(supabaseProvider).rpc('activity').catchError((_) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      ref.watch(sharingControllerProvider);
      ref.watch(appPresenceProvider);
    }
    return widget.child;
  }
}
