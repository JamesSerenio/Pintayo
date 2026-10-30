import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

const reactionEmojis = ['❤️', '😆', '😮', '😢', '😠', '👍'];

class MessageReactions extends ChangeNotifier {
  final SupabaseClient client;
  final String conversation;
  final Map<String, Map<String, String>> values = {};
  late final RealtimeChannel _channel;
  Timer? _timer;
  bool _disposed = false, _loading = false, _again = false;
  final Set<String> pending = {};
  MessageReactions(this.client, this.conversation) {
    _channel =
        client
            .channel('reactions:$conversation')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'message_reactions',
              callback: (_) => refresh(),
            )
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) refresh();
          });
    // Also catch deletions and reconnect gaps, without inventing local reactions.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    refresh();
  }
  Future<void> refresh() async {
    if (_disposed) return;
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    try {
      final result = <String, Map<String, String>>{};
      for (var offset = 0; !_disposed; offset += 500) {
        final rows = await client
            .from('message_reactions')
            .select()
            .eq('conversation_id', conversation)
            .order('message_id')
            .order('owner')
            .range(offset, offset + 499);
        for (final row in rows) {
          result.putIfAbsent(
            row['message_id'] as String,
            () => {},
          )[row['owner'] as String] = row['emoji'] as String;
        }
        if (rows.length < 500) break;
      }
      if (!_disposed) {
        values
          ..clear()
          ..addAll(result);
        notifyListeners();
      }
    } catch (_) {
      // The conversation remains usable before the reaction migration is applied.
    } finally {
      _loading = false;
      if (_again && !_disposed) {
        _again = false;
        refresh();
      }
    }
  }

  Future<void> react(String message, String emoji) async {
    if (!pending.add(message)) return;
    try {
      await client.rpc(
        'react_to_message',
        params: {
          'message_id': message,
          'reaction': values[message]?[client.auth.currentUser!.id] == emoji
              ? null
              : emoji,
        },
      );
      await refresh();
    } finally {
      pending.remove(message);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    client.removeChannel(_channel);
    super.dispose();
  }
}

final messageReactionsProvider = Provider.autoDispose
    .family<MessageReactions, String>((ref, id) {
      final controller = MessageReactions(ref.watch(supabaseProvider), id);
      ref.onDispose(controller.dispose);
      return controller;
    });
