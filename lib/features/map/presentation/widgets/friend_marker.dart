import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../application/map_controller.dart';
import '../../../location_sharing/data/models/shared_location.dart';

class AnimatedFriendLayer extends StatelessWidget {
  final MapControllerState state;
  final ValueChanged<SharedLocation> onSelected;
  const AnimatedFriendLayer({
    super.key,
    required this.state,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(state.locations.values.map((f) => f.fixedAt).join()),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    builder: (_, progress, _) => MarkerLayer(
      markers: state.visible.map((fix) {
        final old = state.previous[fix.owner] ?? fix;
        final person = state.people[fix.owner];
        return Marker(
          width: 96,
          height: 88,
          point: LatLng(
            old.latitude + (fix.latitude - old.latitude) * progress,
            old.longitude + (fix.longitude - old.longitude) * progress,
          ),
          child: Semantics(
            label:
                '${person?.displayName ?? 'Friend'}, ${fix.fresh ? 'recent location' : 'last known location'}',
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(fix),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: fix.fresh ? AppColors.emerald : AppColors.muted,
                        width: 3,
                      ),
                    ),
                    child: ProfileAvatar(
                      name: person?.displayName ?? '?',
                      path: person?.avatarPath,
                      size: 40,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      person?.displayName ?? 'Friend',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}
