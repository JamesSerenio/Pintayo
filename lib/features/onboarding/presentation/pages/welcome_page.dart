import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/brand.dart';
import '../../../../shared/widgets/feedback_views.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const Brand(),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(38),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: const Icon(
                  Icons.share_location_rounded,
                  size: 112,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Closer to your people.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A little less “nasaan ka?”\nA little more time together.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, height: 1.6),
              ),
              const SizedBox(height: 32),
              const InfoCard(
                icon: Icons.lock_outline,
                title: 'Your location, your choice',
                body:
                    'Sharing starts only when you choose your people and duration.',
              ),
              const SizedBox(height: 16),
              const Text(
                'PinTayo is getting ready. Please try again soon.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
