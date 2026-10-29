import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/supabase_provider.dart';

/// Own-device Presence remains private. Only the server-filtered activity lease
/// is visible to friends; OS location publication cannot refresh this lease.
class AppPresenceController {
  final SupabaseClient client;
  final String connection = const Uuid().v4();
  late final RealtimeChannel _channel;
  Timer? _heartbeat;
  bool _active = true, _disposed = false;
  AppPresenceController(this.client) {
    _channel =
        client
            .channel(
              'presence:${client.auth.currentUser!.id}',
              opts: RealtimeChannelConfig(private: true, key: connection),
            )
            .onPresenceSync((_) {})
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) _beat();
          });
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
    _beat();
  }
  Future<void> _beat() async {
    if (_disposed || !_active) return;
    try {
      await client.rpc(
        'activity_tick',
        params: {'connection_id': connection, 'foreground': true},
      );
      await _channel.track({'at': DateTime.now().toUtc().toIso8601String()});
    } catch (_) {
      /* No activity is asserted without a successful server heartbeat. */
    }
  }

  Future<void> setActive(bool value) async {
    _active = value;
    if (value) {
      await _beat();
      return;
    }
    try {
      await _channel.untrack();
      await client.rpc(
        'activity_tick',
        params: {'connection_id': connection, 'foreground': false},
      );
    } catch (_) {
      /* A lost connection expires on the server within 75 seconds. */
    }
  }

  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    setActive(false);
    client.removeChannel(_channel);
  }
}

final appPresenceProvider = Provider.autoDispose((ref) {
  final controller = AppPresenceController(ref.watch(supabaseProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
