import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../features/location_sharing/application/sharing_controller.dart';
import 'feedback_views.dart';

Future<void> openLocationPermissions(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!kIsWeb) {
    await runAction(context, () async {
      final opened = await Geolocator.openAppSettings();
      if (!opened && context.mounted) {
        showNotice(
          context,
          'Open device Settings and allow location for PinTayo.',
        );
      }
    });
    return;
  }
  final retry = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Allow browser location'),
      content: const Text(
        'Tap Allow location below, then choose Allow in the browser prompt. '
        'This only shows your position; sharing stays under your control.\n\n'
        'If you opened PinTayo in Messenger or Facebook, use the browser menu '
        'to open it in Chrome or Safari. You can also copy the link below.\n\n'
        'If access was blocked, open the browser site permissions and allow '
        'Location. Also turn on your phone’s Location services, then try again.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: Uri.base.toString()));
            if (dialogContext.mounted) {
              showNotice(
                dialogContext,
                'Link copied. Paste it into Chrome or Safari.',
              );
            }
          },
          child: const Text('Copy link'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Allow location'),
        ),
      ],
    ),
  );
  if (retry == true && context.mounted) {
    await runAction(
      context,
      () => ref.read(locationTrackerProvider).refreshPosition(),
    );
  }
}
