import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/supabase_provider.dart';

class ImageUploadService {
  final SupabaseClient client;
  ImageUploadService(this.client);
  Future<String?> selectAndUpload(String bucket, {String? conversation}) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return null;
    if (await image.length() > 20 * 1024 * 1024) {
      throw const AppException('Choose a photo smaller than 20 MB.');
    }
    final bytes = await FlutterImageCompress.compressWithList(
      await image.readAsBytes(),
      minWidth: bucket == 'avatars' ? 512 : 1280,
      minHeight: bucket == 'avatars' ? 512 : 1280,
      quality: 80,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (bytes.length > (bucket == 'avatars' ? 2 : 5) * 1024 * 1024) {
      throw const AppException(
        'This photo is too large. Choose a smaller image.',
      );
    }
    final path =
        '${conversation == null ? '' : '$conversation/'}${client.auth.currentUser!.id}/${const Uuid().v4()}.jpg';
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  }

  Future<void> removeAvatar(String path) =>
      client.storage.from('avatars').remove([path]);
}

final imageUploadProvider = Provider(
  (ref) => ImageUploadService(ref.watch(supabaseProvider)),
);
