import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/time_labels.dart';
import '../../chat/data/chat_repository.dart';

class ConversationPresence extends ChangeNotifier {
  final SupabaseClient client;
  final String conversation;
  final String connection = const Uuid().v4();
  RealtimeChannel? _activity;
  Timer? _heartbeat, _typingTimeout;
  bool active = true, partnerActive = false, typing = false, _disposed = false;
  DateTime? _lastTyping, _partnerLastActive;
  bool _partnerHidden = true;

  ConversationPresence(this.client, this.conversation, String? partner) {
    if (partner != null) {
      _activity =
          client
              .channel('activity:$conversation:$connection')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'activity_sessions',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'owner',
                  value: partner,
                ),
                callback: (_) => _sync(),
              )
            ..subscribe();
    }
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
    _beat();
  }
  String get status => _partnerHidden
      ? 'Activity hidden'
      : partnerActive
      ? 'Active now'
      : _partnerLastActive == null
      ? 'Activity unavailable'
      : 'Last active ${timeAgo(_partnerLastActive)}';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _tick({bool isTyping = false}) async {
    await client.rpc(
      'activity_tick',
      params: {
        'connection_id': connection,
        'foreground': active,
        'chat': conversation,
        'is_typing': isTyping,
      },
    );
  }

  Future<void> _beat() async {
    if (_disposed || !active) return;
    try {
      await _tick();
      await _sync();
    } catch (_) {
      partnerActive = false;
      _notify();
    }
  }

  Future<void> _sync() async {
    if (_disposed) return;
    try {
      final data = await client.rpc(
        'chat_activity',
        params: {'chat': conversation},
      );
      _partnerHidden = data == null || data['hidden'] == true;
      _partnerLastActive = DateTime.tryParse(data?['last_active'] ?? '');
      partnerActive = !_partnerHidden && data?['active'] == true;
      typing = !_partnerHidden && active && data?['typing'] == true;
      _typingTimeout?.cancel();
      if (typing) {
        _typingTimeout = Timer(const Duration(seconds: 5), () {
          typing = false;
          _notify();
        });
      }
      _notify();
    } catch (_) {
      partnerActive = false;
      typing = false;
      _notify();
    }
  }

  Future<void> setActive(bool value) async {
    active = value;
    try {
      if (value) {
        await _beat();
      } else {
        await _tick();
      }
    } catch (_) {
      /* The next foreground heartbeat recovers. */
    }
  }

  void changedText(String text) {
    if (!active) return;
    if (_lastTyping != null &&
        DateTime.now().difference(_lastTyping!).inSeconds < 2 &&
        text.isNotEmpty) {
      return;
    }
    _lastTyping = DateTime.now();
    _tick(isTyping: text.isNotEmpty).catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _typingTimeout?.cancel();
    active = false;
    _tick().catchError((Object _) {});
    if (_activity != null) client.removeChannel(_activity!);
    super.dispose();
  }
}

final conversationPresenceProvider = Provider.autoDispose
    .family<ConversationPresence, String>((ref, id) {
      final partner = ref.watch(chatPartnerProvider(id)).asData?.value;
      final controller = ConversationPresence(
        ref.watch(supabaseProvider),
        id,
        partner?.id,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
