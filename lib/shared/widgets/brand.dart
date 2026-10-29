import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, color: AppColors.emerald, size: 38),
          Text(
            'PinTayo',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ),
      Text(
        'Magkita sa mapa.',
        style: TextStyle(color: AppColors.emerald, letterSpacing: 1.4),
      ),
    ],
  );
}
