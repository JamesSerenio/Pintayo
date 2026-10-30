import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../../../shared/widgets/photo_viewer.dart';

/// A loose constraint lets the decoded image determine its aspect ratio.
/// No fixed-height crop and no colored wrapper behind image-only messages.
class ImageMessage extends ConsumerWidget {
  final String path;
  const ImageMessage({super.key, required this.path});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(signedImageProvider(('attachments', path)));
    return Semantics(
      button: true,
      label: 'Open photo',
      child: GestureDetector(
        onTap: () =>
            openPhotoViewer(context, bucket: 'attachments', path: path),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 360),
            child: image.when(
              data: (url) => Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 160,
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
              loading: () => const SizedBox(
                width: 160,
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => SizedBox(
                width: 160,
                height: 120,
                child: Center(
                  child: IconButton(
                    tooltip: 'Retry photo',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(
                      signedImageProvider(('attachments', path)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
