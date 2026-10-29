import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class Meetup {
  final String id, title;
  final double latitude, longitude;
  final DateTime expiresAt;
  const Meetup(
    this.id,
    this.title,
    this.latitude,
    this.longitude,
    this.expiresAt,
  );
}

class MeetupsRepository {
  final SupabaseClient client;
  MeetupsRepository(this.client);
  Future<List<Map<String, dynamic>>> people(String id) async {
    final result = await client.rpc('meetup_people', params: {'meetup': id});
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Meetup>> list() async {
    final rows = await client
        .from('meetups')
        .select()
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .limit(50);
    return rows
        .map(
          (r) => Meetup(
            r['id'],
            r['title'],
            (r['latitude'] as num).toDouble(),
            (r['longitude'] as num).toDouble(),
            DateTime.parse(r['expires_at']),
          ),
        )
        .toList();
  }

  Future<void> create(
    String title,
    double lat,
    double lng,
    List<String> guests,
    String? circle,
  ) async => client.rpc(
    'create_meetup',
    params: {
      'title': title,
      'lat': lat,
      'lng': lng,
      'guests': guests,
      'circle': circle,
    },
  );
  Future<void> status(String meetup, String status) async => client.rpc(
    'meetup_status',
    params: {'meetup': meetup, 'new_status': status},
  );
}

final meetupsRepositoryProvider = Provider(
  (ref) => MeetupsRepository(ref.watch(supabaseProvider)),
);
final meetupsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(meetupsRepositoryProvider).list(),
);
final meetupPeopleProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(meetupsRepositoryProvider).people(id),
);
