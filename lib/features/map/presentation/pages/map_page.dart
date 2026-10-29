import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../shared/widgets/location_permission_action.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../circles/data/circles_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../location_sharing/application/sharing_controller.dart';
import '../../../location_sharing/presentation/widgets/sharing_status_card.dart';
import '../../data/map_tile_provider.dart';
import '../../../meetups/presentation/widgets/meetup_panel.dart';
import '../../../meetups/data/meetups_repository.dart';
import '../../application/map_controller.dart';
import '../widgets/friend_marker.dart';
import '../widgets/own_profile_marker.dart';
import '../widgets/selected_profile_sheet.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _map = MapController();
  late final TileProvider _tiles = ref.read(tileProviderFactoryProvider)();
  bool _follow = true, _tileError = false, _ready = false;
  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapStateProvider);
    final tracker = ref.watch(locationTrackerProvider);
    final sharing = ref.watch(sharingControllerProvider);
    final config = ref.watch(configProvider);
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final circles = ref.watch(circlesProvider).asData?.value ?? [];
    final friends = ref.watch(friendsProvider).asData?.value ?? [];
    final meetups = ref.watch(meetupsProvider).asData?.value ?? [];
    return ListenableBuilder(
      listenable: Listenable.merge([state, tracker, sharing]),
      builder: (_, _) {
        final own = tracker.position;
        if (_ready && _follow && own != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _ready) {
              _map.move(
                LatLng(own.latitude, own.longitude),
                _map.camera.zoom < 10 ? 15 : _map.camera.zoom,
              );
            }
          });
        }
        final session = sharing.session;
        final audience = session == null
            ? ''
            : [
                ...session.friends.map(
                  (id) =>
                      friends
                          .where((f) => f.person.id == id)
                          .firstOrNull
                          ?.person
                          .displayName ??
                      'Selected friend',
                ),
                ...session.circles.map(
                  (id) =>
                      circles.where((c) => c.id == id).firstOrNull?.name ??
                      'Selected circle',
                ),
              ].join(', ');
        return Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: own == null
                    ? const LatLng(12.8, 122.5)
                    : LatLng(own.latitude, own.longitude),
                initialZoom: own == null ? 5 : 15,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () {
                  _ready = true;
                },
                onPositionChanged: (_, gesture) {
                  if (gesture && _follow) setState(() => _follow = false);
                },
                onLongPress: (_, point) => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MeetupPanel(point: point),
                ),
              ),
              children: [
                TileLayer(
                  tileProvider: _tiles,
                  urlTemplate: config.tileUrl,
                  userAgentPackageName: config.appId,
                  panBuffer: 0,
                  maxZoom: 19,
                  maxNativeZoom: 19,
                  errorTileCallback: (_, _, _) {
                    if (!_tileError) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _tileError = true);
                      });
                    }
                  },
                ),
                if (own != null && own.accuracy.isFinite && own.accuracy > 0)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(own.latitude, own.longitude),
                        radius: own.accuracy,
                        useRadiusInMeter: true,
                        color: AppColors.emerald.withValues(alpha: 0.08),
                        borderColor: AppColors.emerald.withValues(alpha: 0.25),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                AnimatedFriendLayer(
                  state: state,
                  onSelected: (fix) => showModalBottomSheet(
                    context: context,
                    builder: (_) => SelectedProfileSheet(
                      location: fix,
                      person: state.people[fix.owner],
                    ),
                  ),
                ),
                MarkerLayer(
                  markers: [
                    if (own != null)
                      Marker(
                        point: LatLng(own.latitude, own.longitude),
                        width: 96,
                        height: 108,
                        // The avatar's center marks the actual coordinate.
                        alignment: const Alignment(0, -0.26),
                        child: OwnProfileMarker(
                          name: profile?.displayName ?? 'You',
                          avatarPath: profile?.avatarPath,
                        ),
                      ),
                    ...meetups.map(
                      (m) => Marker(
                        point: LatLng(m.latitude, m.longitude),
                        width: 44,
                        height: 44,
                        child: IconButton(
                          tooltip: m.title,
                          icon: const Icon(
                            Icons.flag_circle,
                            color: AppColors.navy,
                            size: 36,
                          ),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            builder: (_) => MeetupDetails(meetup: m),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.emerald,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Magkita sa mapa.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          DropdownButton<String>(
                            value: state.circleId ?? '',
                            underline: const SizedBox(),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Everyone'),
                              ),
                              ...circles
                                  .where((c) => c.accepted)
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                            ],
                            onChanged: (id) => runAction(
                              context,
                              () => state.selectCircle(id == '' ? null : id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.error != null ||
                      tracker.problem != null ||
                      _tileError)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          tracker.problem ??
                              state.error ??
                              'Some map tiles couldnâ€™t load. Check your connection.',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 20,
              bottom: 225,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Recenter and follow',
                    backgroundColor: Colors.white,
                    onPressed: () => runAction(context, () async {
                      await tracker.refreshPosition();
                      if (mounted) setState(() => _follow = true);
                    }),
                    child: Icon(
                      _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Location settings',
                    backgroundColor: Colors.white,
                    onPressed: () => openLocationPermissions(context, ref),
                    child: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: SharingStatusCard(
                sharing: sharing,
                audience: audience,
                visibleCount: state.visible.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
