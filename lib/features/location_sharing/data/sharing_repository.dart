import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import 'models/shared_location.dart';

class SharingSession {
  final String id, state;
  final DateTime? expiresAt;
  final List<String> friends, circles;
  const SharingSession(
    this.id,
    this.state,
    this.expiresAt,
    this.friends,
    this.circles,
  );
  bool get expired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());
}

class SharingRepository {
  final SupabaseClient client;
  SharingRepository(this.client);
  Future<SharingSession?> session() async {
    final row = await client
        .from('sharing_sessions')
        .select()
        .eq('owner', client.auth.currentUser!.id)
        .neq('state', 'stopped')
        .maybeSingle();
    if (row == null) return null;
    final recipients = await client
        .from('sharing_recipients')
        .select()
        .eq('session_id', row['id']);
    return SharingSession(
      row['id'],
      row['state'],
      DateTime.tryParse(row['expires_at'] ?? ''),
      recipients.map((r) => r['friend_id']).whereType<String>().toList(),
      recipients.map((r) => r['circle_id']).whereType<String>().toList(),
    );
  }

  Future<void> start(
    List<String> friends,
    List<String> circles,
    int minutes,
  ) async => client.rpc(
    'share_start',
    params: {'friends': friends, 'circles': circles, 'minutes': minutes},
  );
  Future<void> setState(String state) async =>
      client.rpc('share_state', params: {'new_state': state});
  Future<List<SharedLocation>> locations() async {
    final rows = await client
        .from('location_inbox')
        .select()
        .eq('recipient', client.auth.currentUser!.id)
        .limit(100);
    return rows.map(SharedLocation.fromJson).toList();
  }

  Future<void> publish(
    double lat,
    double lng,
    double accuracy,
    DateTime time,
  ) async => client.rpc(
    'publish_location',
    params: {
      'lat': lat,
      'lng': lng,
      'accuracy_m': accuracy,
      'fix_time': time.toUtc().toIso8601String(),
    },
  );
}

final sharingRepositoryProvider = Provider(
  (ref) => SharingRepository(ref.watch(supabaseProvider)),
);
final sharingSessionProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(sharingRepositoryProvider).session(),
);
