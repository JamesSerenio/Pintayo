import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../application/sharing_controller.dart';
import 'sharing_panel.dart';

class SharingStatusCard extends StatelessWidget {
  final SharingController sharing;
  final String audience;
  final int visibleCount;
  const SharingStatusCard({
    super.key,
    required this.sharing,
    required this.audience,
    required this.visibleCount,
  });
  @override
  Widget build(BuildContext context) {
    final session = sharing.session;
    final active =
        session != null && !session.expired && session.state == 'active';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.share_location : Icons.lock_outline,
                  color: AppColors.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !sharing.checked
                        ? sharing.error == null
                              ? 'Checking sharing status…'
                              : 'Sharing status unavailable'
                        : active
                        ? 'Sharing with $audience'
                        : session?.state == 'paused'
                        ? 'Sharing paused'
                        : 'Your location is private',
                    maxLines: 2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (session != null && !session.expired)
              Text(
                session.expiresAt == null
                    ? 'Until you stop sharing'
                    : 'Ends ${TimeOfDay.fromDateTime(session.expiresAt!.toLocal()).format(context)}',
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              visibleCount == 0
                  ? 'No one is sharing with you yet. Long-press the map to plan a meet-up.'
                  : '$visibleCount shared locations · check each fix time',
              style: const TextStyle(fontSize: 12),
            ),
            if (sharing.error != null)
              Text(
                sharing.error!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            const SizedBox(height: 12),
            if (session == null || session.expired)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const SharingPanel(),
                  ),
                  child: const Text('Choose who to share with'),
                ),
              )
            else
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: () => runAction(
                      context,
                      () => sharing.change(active ? 'paused' : 'active'),
                    ),
                    child: Text(active ? 'Pause' : 'Resume'),
                  ),
                  TextButton(
                    onPressed: () =>
                        runAction(context, () => sharing.change('stopped')),
                    child: const Text('Stop sharing'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
