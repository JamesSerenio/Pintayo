import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/private_image.dart';

class OwnProfileMarker extends StatelessWidget {
  final String name;
  final String? avatarPath;

  const OwnProfileMarker({super.key, required this.name, this.avatarPath});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name, your current location',
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emerald.withValues(alpha: 0.12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: _LocationGlow()),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.emerald, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ProfileAvatar(name: name, path: avatarPath, size: 48),
              ),
              Positioned(
                bottom: -4,
                left: 21,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: const Text(
            'You',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _LocationGlow extends StatefulWidget {
  const _LocationGlow();

  @override
  State<_LocationGlow> createState() => _LocationGlowState();
}

class _LocationGlowState extends State<_LocationGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: List.generate(2, (index) {
            final progress = (_pulse.value + index * 0.5) % 1;
            final opacity = (1 - progress) * 0.24;
            return Transform.scale(
              scale: 1 + progress * 0.85,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emerald.withValues(alpha: opacity * 0.45),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: opacity),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withValues(alpha: opacity),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
