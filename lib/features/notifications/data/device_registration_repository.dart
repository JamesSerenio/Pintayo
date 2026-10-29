import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

abstract interface class DeviceRegistrations {
  String? get currentUserId;
  Stream<String?> get accountChanges;
  Future<void> save({
    required String user,
    required String installation,
    required String registration,
  });
  Future<void> remove(String installation, {String? registration});
}

class DeviceRegistrationRepository implements DeviceRegistrations {
  final SupabaseClient client;
  final String platform;
  DeviceRegistrationRepository(this.client, this.platform);
  @override
  String? get currentUserId => client.auth.currentUser?.id;
  @override
  Stream<String?> get accountChanges =>
      client.auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();
  @override
  Future<void> save({
    required String user,
    required String installation,
    required String registration,
  }) async {
    await client.rpc(
      'register_push_device',
      params: {
        'expected_user': user,
        'installation_id': installation,
        'registration': registration,
        'device_platform': platform,
      },
    );
  }

  @override
  Future<void> remove(String installation, {String? registration}) async {
    final user = currentUserId;
    if (user == null) return;
    var query = client
        .from('devices')
        .delete()
        .eq('owner', user)
        .eq('installation', installation);
    if (registration != null) query = query.eq('token', registration);
    await query;
  }
}

final deviceRegistrationRepositoryProvider = Provider<DeviceRegistrations>(
  (ref) => DeviceRegistrationRepository(
    ref.watch(supabaseProvider),
    ref.watch(devicePlatformProvider),
  ),
);
