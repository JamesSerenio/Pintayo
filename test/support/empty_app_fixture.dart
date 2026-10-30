import 'package:pintayo/features/friends/application/request_attention.dart';
import 'package:pintayo/features/presence/application/online_friends.dart';
// Explicit empty-state test fixture. No fake friends or coordinates in the app.
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pintayo/app/theme/app_theme.dart';
import 'package:pintayo/core/config/app_config.dart';
import 'package:pintayo/core/network/connectivity_service.dart';
import 'package:pintayo/features/circles/data/circles_repository.dart';
import 'package:pintayo/features/friends/data/friends_repository.dart';
import 'package:pintayo/features/chat/data/chat_repository.dart';
import 'package:pintayo/features/meetups/data/meetups_repository.dart';
import 'package:pintayo/features/map/application/map_controller.dart';
import 'package:pintayo/features/map/data/map_tile_provider.dart';
import 'package:pintayo/features/location_sharing/application/sharing_controller.dart';
import 'package:pintayo/features/location_sharing/data/location_tracker.dart';
import 'package:pintayo/features/location_sharing/data/sharing_repository.dart';
import 'package:pintayo/features/location_sharing/data/models/shared_location.dart';
import 'package:pintayo/features/profile/data/profile_repository.dart';

class EmptySharingRepository extends SharingRepository {
  EmptySharingRepository(super.client);
  @override
  Future<SharingSession?> session() async => null;
  @override
  Future<List<SharedLocation>> locations() async => [];
}

class NoDeviceTracker extends LocationTracker {
  NoDeviceTracker(super.repository, super.config);
  @override
  Future<void> restore({required bool publish}) async {}
}

class TransparentTiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
    ),
  );
}

Widget emptyAppFixture(
  Widget child, {
  List<Conversation> chats = const [],
  List<Friendship> friends = const [],
  Set<String> online = const {},
}) {
  final client = SupabaseClient(
    'https://test.invalid',
    'test-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final sharing = EmptySharingRepository(client);
  final profile = ProfileRepository(client);
  final circles = CirclesRepository(client);
  final connectivity = ConnectivityService(Connectivity());
  return ProviderScope(
    overrides: [
      currentProfileProvider.overrideWith((ref) async => null),
      requestAttentionProvider.overrideWith((ref) {
        final value = RequestAttention('empty-fixture');
        ref.onDispose(value.dispose);
        return value;
      }),
      onlineFriendsProvider.overrideWith((ref) => Stream.value(online)),
      friendsProvider.overrideWith((ref) async => friends),
      circlesProvider.overrideWith((ref) async => []),
      conversationsProvider.overrideWith((ref) async => chats),
      meetupsProvider.overrideWith((ref) async => []),
      sharingRepositoryProvider.overrideWithValue(sharing),
      locationTrackerProvider.overrideWith((ref) {
        final tracker = NoDeviceTracker(
          sharing,
          const AppConfig(supabaseUrl: '', supabaseKey: ''),
        );
        ref.onDispose(tracker.dispose);
        return tracker;
      }),
      mapStateProvider.overrideWith((ref) {
        final state = MapControllerState(
          sharing,
          profile,
          circles,
          connectivity,
          subscribeToRealtime: false,
        );
        ref.onDispose(state.dispose);
        return state;
      }),
      tileProviderFactoryProvider.overrideWithValue(() => TransparentTiles()),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: child),
  );
}
