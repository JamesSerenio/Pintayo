import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pintayo/core/config/app_config.dart';

void main() {
  test(
    'installed Supabase SDK separates the public API key from the signed-in user session',
    () async {
      const config = AppConfig.environment();
      final publicKey = config.isConfigured
          ? config.supabaseKey
          : 'sb_publishable_test_only_fixture';
      const id = '00000000-0000-4000-8000-000000000001';
      String encoded(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final expires =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      final access =
          '${encoded({'alg': 'HS256', 'typ': 'JWT'})}.${encoded({'sub': id, 'role': 'authenticated', 'exp': expires})}.test-signature';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <({bool correctApiKey, bool userJwt, String path})>[];
      final listener = server.listen((request) async {
        received.add((
          correctApiKey: request.headers.value('apikey') == publicKey,
          userJwt: request.headers.value('authorization') == 'Bearer $access',
          path: request.uri.path,
        ));
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/auth/v1/token') {
          request.response.write(
            jsonEncode({
              'access_token': access,
              'refresh_token': 'test-only-refresh',
              'expires_in': 3600,
              'expires_at': expires,
              'token_type': 'bearer',
              'user': {
                'id': id,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'fixture@example.invalid',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': DateTime.now().toIso8601String(),
              },
            }),
          );
        } else {
          request.response.write('[]');
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        publicKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await client.dispose();
        await listener.cancel();
        await server.close(force: true);
      });
      await client.from('profiles').select('id').limit(0);
      expect(client.auth.currentSession, isNull);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'test-only-password',
      );
      await client.from('profiles').select('id').limit(0);
      expect(received.every((request) => request.correctApiKey), isTrue);
      expect(received.last.path, '/rest/v1/profiles');
      expect(
        received.last.userJwt,
        isTrue,
        reason: 'Authenticated data requests must use the user session JWT',
      );
    },
  );
}
