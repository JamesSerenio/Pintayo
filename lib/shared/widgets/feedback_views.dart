import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/errors/app_exception.dart';

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget? action;
  const EmptyView({
    super.key,
    this.icon = Icons.people_outline,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.emerald),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.cloud_off,
    title: 'Let’s try that again',
    description: 'We couldn’t load this. Check your connection.',
    action: FilledButton(onPressed: onRetry, child: const Text('Try again')),
  );
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.emerald),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(height: 1.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void showNotice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<void> runAction(
  BuildContext context,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (error) {
    if (context.mounted) showNotice(context, readableError(error));
  }
}
