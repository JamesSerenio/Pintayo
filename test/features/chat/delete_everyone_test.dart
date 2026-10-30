import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pintayo/features/chat/data/message_actions_repository.dart';
import 'package:pintayo/core/errors/app_exception.dart';

void main() {
  for (final allowed in [true, false]) {
    test(
      allowed
          ? 'global delete succeeds when the cleanup Edge Function is missing'
          : 'sender rejection is preserved and cleanup is not attempted',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final cleanup = Completer<void>();
        final paths = <String>[];
        final subscription = server.listen((request) async {
          paths.add(request.uri.path);
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          request.response.headers.contentType = ContentType.json;
          if (request.uri.path == '/rest/v1/rpc/delete_message_everyone') {
            expect(body, {'message_id': 'test-message'});
            request.response.statusCode = allowed ? 200 : 403;
            request.response.write(
              allowed
                  ? 'null'
                  : jsonEncode({
                      'code': 'P0001',
                      'message': 'Only the sender can delete this message',
                    }),
            );
          } else {
            request.response.statusCode = 404;
            request.response.write(
              jsonEncode({
                'code': 'NOT_FOUND',
                'message': 'Function not found',
              }),
            );
          }
          await request.response.close();
          if (request.uri.path.startsWith('/functions/')) cleanup.complete();
        });
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'test-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(() async {
          await client.dispose();
          await subscription.cancel();
          await server.close(force: true);
        });
        final repository = MessageActionsRepository(client);
        if (allowed) {
          await repository.deleteEveryone('test-message');
          await cleanup.future.timeout(const Duration(seconds: 3));
          await Future<void>.delayed(Duration.zero);
          expect(paths.first, '/rest/v1/rpc/delete_message_everyone');
          expect(paths.last, '/functions/v1/message-actions');
        } else {
          await expectLater(
            repository.deleteEveryone('test-message'),
            throwsA(isA<AppException>()),
          );
          expect(paths, ['/rest/v1/rpc/delete_message_everyone']);
        }
      },
    );
  }
}
