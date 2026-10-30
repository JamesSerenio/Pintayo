import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'private_image.dart';

Future<void> openPhotoViewer(
  BuildContext context, {
  required String bucket,
  required String path,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PhotoViewer(bucket: bucket, path: path),
  ),
);

class _PhotoViewer extends ConsumerWidget {
  final String bucket, path;
  const _PhotoViewer({required this.bucket, required this.path});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(signedImageProvider((bucket, path)));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Close photo',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Photo'),
      ),
      body: SafeArea(
        child: photo.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (_, _) => Center(
            child: TextButton.icon(
              onPressed: () =>
                  ref.invalidate(signedImageProvider((bucket, path))),
              icon: const Icon(Icons.refresh),
              label: const Text('Photo unavailable. Retry'),
            ),
          ),
          data: (url) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: SizedBox.expand(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Photo could not load.',
                    style: TextStyle(color: Colors.white),
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
