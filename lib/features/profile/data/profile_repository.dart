import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import 'models/profile.dart';

class ProfileRepository {
  final SupabaseClient client;
  ProfileRepository(this.client);
  Future<Profile?> current() async {
    final row = await client
        .from('profiles')
        .select()
        .eq('id', client.auth.currentUser!.id)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<Profile?> person(String id) async {
    final row = await client.rpc('person', params: {'person_id': id});
    return row == null
        ? null
        : Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> save({
    required String username,
    required String displayName,
    required String firstName,
    required String lastName,
    String? avatarPath,
    bool onboarded = true,
    bool hideActivity = false,
  }) async {
    final values = {
      'username': username.trim(),
      'display_name': displayName.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'avatar_path': avatarPath,
      'onboarded': onboarded,
      'hide_activity': hideActivity,
    };
    final id = client.auth.currentUser!.id;
    if (await current() == null) {
      await client.from('profiles').insert({'id': id, ...values});
    } else {
      await client.from('profiles').update(values).eq('id', id);
    }
  }

  Future<void> setActivityHidden(bool value) async => client
      .from('profiles')
      .update({'hide_activity': value})
      .eq('id', client.auth.currentUser!.id);
}

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(supabaseProvider)),
);
final currentProfileProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).current(),
);
