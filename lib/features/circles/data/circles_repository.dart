import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class Circle {
  final String id, name, owner;
  final bool accepted;
  const Circle(this.id, this.name, this.owner, this.accepted);
}

class CirclesRepository {
  final SupabaseClient client;
  CirclesRepository(this.client);
  Future<List<Circle>> list() async {
    final rows = await client.rpc('my_circles');
    return (rows as List)
        .map((r) => Circle(r['id'], r['name'], r['owner'], r['accepted']))
        .toList();
  }

  Future<List<String>> members(String id) async {
    final rows = await client
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', id)
        .eq('accepted', true)
        .limit(100);
    return rows.map((r) => r['user_id'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> people(String id) async {
    final result = await client.rpc('circle_people', params: {'circle': id});
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> act(
    String action, {
    String? circle,
    String? target,
    String? title,
  }) async => client.rpc(
    'circle_action',
    params: {
      'action': action,
      'circle': circle,
      'target': target,
      'title': title,
    },
  );
}

final circlesRepositoryProvider = Provider(
  (ref) => CirclesRepository(ref.watch(supabaseProvider)),
);
final circlesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(circlesRepositoryProvider).list(),
);
