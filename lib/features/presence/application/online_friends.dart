import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

/// Activity rows are filtered by RLS for accepted friends and hidden status.
/// Refresh expiry even when no new events arrive after a friend disconnects.
final onlineFriendsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final client = ref.watch(supabaseProvider);
  final output = StreamController<Set<String>>();
  var disposed = false;
  var busy = false;
  Future<void> refresh() async {
    if (busy ||
        disposed ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    busy = true;
    try {
      final rows = await client
          .from('activity_sessions')
          .select('owner')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      if (!disposed) {
        output.add(rows.map((row) => row['owner'] as String).toSet());
      }
    } catch (_) {
      if (!disposed) output.add({});
    } finally {
      busy = false;
    }
  }

  final channel =
      client
          .channel('online-friends:${client.auth.currentUser!.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'activity_sessions',
            callback: (_) => refresh(),
          )
        ..subscribe();
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  refresh();
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    client.removeChannel(channel);
    output.close();
  });
  return output.stream;
});
