import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pintayo/features/chat/data/message_copy_service.dart';
import 'package:pintayo/features/chat/data/models/message.dart';

class _UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected network request');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;
  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = call.arguments['text'];
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  test('copy writes complete text without UI labels or timestamps', () async {
    const body = 'Kumusta?\nComplete message ❤️';
    final result = await copyMessage(
      Message(
        id: 'id',
        conversationId: 'chat',
        sender: 'self',
        body: body,
        createdAt: DateTime.now(),
      ),
      _UnusedClient(),
    );
    expect(clipboard, body);
    expect(result, 'Message copied.');
  });
  test(
    'unsupported image copying never copies a private path or URL',
    () async {
      final result = await copyMessage(
        Message(
          id: 'id',
          conversationId: 'chat',
          sender: 'self',
          attachment: 'private/photo.jpg',
          createdAt: DateTime.now(),
        ),
        _UnusedClient(),
      );
      expect(clipboard, isNull);
      expect(result, contains('not supported'));
    },
  );
  test('a caption can still be copied on a text-only clipboard', () async {
    final result = await copyMessage(
      Message(
        id: 'id',
        conversationId: 'chat',
        sender: 'self',
        body: 'My caption',
        attachment: 'private/photo.jpg',
        createdAt: DateTime.now(),
      ),
      _UnusedClient(),
    );
    expect(clipboard, 'My caption');
    expect(result, startsWith('Caption copied.'));
  });
}
