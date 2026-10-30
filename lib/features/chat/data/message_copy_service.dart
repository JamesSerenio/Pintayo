import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_clipboard.dart';
import 'models/message.dart';

Future<String> copyMessage(Message message, SupabaseClient client) async {
  if (message.deleted) return 'Message unavailable.';
  if (message.attachment != null) {
    final copied = await copyImage(
      () => client.storage.from('attachments').download(message.attachment!),
      caption: message.body,
    );
    if (copied) return 'Photo copied.';
    if (message.body?.isNotEmpty != true) {
      return 'Copying photos is not supported in this browser or device. You can open the photo to view it.';
    }
  }
  await Clipboard.setData(ClipboardData(text: message.body ?? ''));
  return message.attachment == null
      ? 'Message copied.'
      : 'Caption copied. Photo copying is not supported on this device.';
}
