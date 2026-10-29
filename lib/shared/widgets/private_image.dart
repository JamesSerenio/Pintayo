import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';

final signedImageProvider = FutureProvider.autoDispose
    .family<String, (String, String)>(
      (ref, key) => ref
          .watch(supabaseProvider)
          .storage
          .from(key.$1)
          .createSignedUrl(key.$2, 900),
    );

class PrivateImage extends ConsumerWidget {
  final String bucket, path;
  final bool avatar;
  final double size;
  const PrivateImage({
    super.key,
    required this.bucket,
    required this.path,
    this.avatar = false,
    this.size = 48,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(signedImageProvider((bucket, path)));
    final child = image.when(
      data: (url) => Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      ),
      error: (_, _) => const Icon(Icons.image_not_supported_outlined),
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
    return avatar
        ? ClipOval(
            child: SizedBox(width: size, height: size, child: child),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 220, child: child),
          );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? path;
  final double size;
  const ProfileAvatar({
    super.key,
    required this.name,
    this.path,
    this.size = 48,
  });
  @override
  Widget build(BuildContext context) => path != null
      ? PrivateImage(bucket: 'avatars', path: path!, avatar: true, size: size)
      : CircleAvatar(
          radius: size / 2,
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
        );
}
