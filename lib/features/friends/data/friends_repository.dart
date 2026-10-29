import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../profile/data/models/profile.dart';
import '../../profile/data/profile_repository.dart';

class Friendship {
  final String id;
  final Profile person;
  final bool accepted, incoming;
  const Friendship(
    this.id,
    this.person, {
    required this.accepted,
    required this.incoming,
  });
}

class FriendsRepository {
  final SupabaseClient client;
  final ProfileRepository profiles;
  FriendsRepository(this.client, this.profiles);
  Future<List<Friendship>> list() async {
    final uid = client.auth.currentUser!.id;
    final rows = await client
        .from('friendships')
        .select()
        .or('requester.eq.$uid,recipient.eq.$uid')
        .order('created_at', ascending: false)
        .limit(100);
    final result = <Friendship>[];
    for (final row in rows) {
      final person = await profiles.person(
        row['requester'] == uid ? row['recipient'] : row['requester'],
      );
      if (person != null) {
        result.add(
          Friendship(
            row['id'],
            person,
            accepted: row['status'] == 'accepted',
            incoming: row['recipient'] == uid,
          ),
        );
      }
    }
    return result;
  }

  Future<List<Profile>> search(String query) async {
    final rows = await client.rpc(
      'search_people',
      params: {'query': query.trim()},
    );
    return (rows as List)
        .map((r) => Profile.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> act(String target, String action) async => client.rpc(
    'friend_action',
    params: {'target_id': target, 'action': action},
  );
  Future<List<String>> blocks() async {
    final rows = await client
        .from('blocks')
        .select('target')
        .eq('owner', client.auth.currentUser!.id)
        .limit(100);
    return rows.map((r) => r['target'] as String).toList();
  }
}

final friendsRepositoryProvider = Provider(
  (ref) => FriendsRepository(
    ref.watch(supabaseProvider),
    ref.watch(profileRepositoryProvider),
  ),
);
final friendsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(friendsRepositoryProvider).list(),
);
final blocksProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(friendsRepositoryProvider).blocks(),
);
