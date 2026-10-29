import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/connectivity_service.dart';
import '../../circles/data/circles_repository.dart';
import '../../location_sharing/data/models/shared_location.dart';
import '../../location_sharing/data/sharing_repository.dart';
import '../../profile/data/models/profile.dart';
import '../../profile/data/profile_repository.dart';

class MapControllerState extends ChangeNotifier {
  final SharingRepository repository;
  final ProfileRepository profiles;
  final CirclesRepository circles;
  final ConnectivityService connectivity;
  Map<String, SharedLocation> locations = {}, previous = {};
  final Map<String, Profile> people = {};
  Set<String>? selectedMembers;
  String? circleId, error;
  bool loading = true, _disposed = false;
  RealtimeChannel? _channel;
  StreamSubscription<bool>? _network;
  Timer? _refresh;
  MapControllerState(
    this.repository,
    this.profiles,
    this.circles,
    this.connectivity, {
    bool subscribeToRealtime = true,
  }) {
    if (subscribeToRealtime) {
      _channel =
          repository.client
              .channel('map:${repository.client.auth.currentUser!.id}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'location_inbox',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'recipient',
                  value: repository.client.auth.currentUser!.id,
                ),
                callback: (event) {
                  if (event.newRecord.isNotEmpty) {
                    _receive(SharedLocation.fromJson(event.newRecord));
                  } else {
                    refresh();
                  }
                },
              )
            ..subscribe((status, _) {
              if (status == RealtimeSubscribeStatus.subscribed) refresh();
            });
      _network = connectivity.changes.listen((online) {
        if (online) refresh();
      });
      // Remove revoked/expired access and update freshness labels. This is not GPS.
      _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
        if (locations.isNotEmpty) refresh();
      });
    }
    refresh();
  }
  Iterable<SharedLocation> get visible => locations.values.where(
    (fix) => selectedMembers == null || selectedMembers!.contains(fix.owner),
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _receive(SharedLocation fix) async {
    if (!fix.newerThan(locations[fix.owner])) return;
    previous = Map.of(locations);
    locations[fix.owner] = fix;
    if (!people.containsKey(fix.owner)) {
      final person = await profiles.person(fix.owner);
      if (person != null) people[fix.owner] = person;
    }
    _notify();
  }

  Future<void> refresh() async {
    try {
      final fixes = await repository.locations();
      final allowed = fixes.map((f) => f.owner).toSet();
      locations.removeWhere((id, _) => !allowed.contains(id));
      for (final fix in fixes) {
        await _receive(fix);
      }
      error = null;
    } catch (_) {
      error = 'Map updates are unavailable. Shown locations are last known.';
    }
    loading = false;
    _notify();
  }

  Future<void> selectCircle(String? id) async {
    circleId = id;
    selectedMembers = id == null ? null : (await circles.members(id)).toSet();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _network?.cancel();
    _refresh?.cancel();
    if (_channel != null) repository.client.removeChannel(_channel!);
    super.dispose();
  }
}

final mapStateProvider = Provider.autoDispose((ref) {
  final controller = MapControllerState(
    ref.watch(sharingRepositoryProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(circlesRepositoryProvider),
    ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
