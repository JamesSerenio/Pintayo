import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/core/config/app_config.dart';

void main() {
  test('publishable keys are accepted without requiring JWT syntax', () {
    const config = AppConfig(
      supabaseUrl: 'https://test-project.supabase.co',
      supabaseKey: 'sb_publishable_test_only',
      supabaseProjectRef: 'test-project',
      firebaseProjectId: 'pintayo',
      firebaseMessagingSenderId: '759625922563',
    );
    expect(config.validate, returnsNormally);
  });
  test(
    'server secrets and project-ref mismatches are rejected without echoing values',
    () {
      expect(
        () => const AppConfig(
          supabaseUrl: 'https://one.supabase.co',
          supabaseKey: 'sb_secret_test_only',
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const AppConfig(
          supabaseUrl: 'https://one.supabase.co',
          supabaseKey: 'public',
          supabaseProjectRef: 'two',
        ).validate(),
        throwsArgumentError,
      );
    },
  );
  test(
    'build-time configuration matches the supplied configuration file',
    () async {
      const config = AppConfig.environment();
      if (!config.isConfigured) return;
      final values = jsonDecode(
        await File('config/app_config.json').readAsString(),
      );
      expect(config.supabaseUrl == values['SUPABASE_URL'], isTrue);
      expect(config.supabaseKey == values['SUPABASE_PUBLISHABLE_KEY'], isTrue);
      expect(config.firebaseProjectId == values['FIREBASE_PROJECT_ID'], isTrue);
      expect(
        config.firebaseMessagingSenderId ==
            values['FIREBASE_MESSAGING_SENDER_ID'],
        isTrue,
      );
      expect(config.validate, returnsNormally);
    },
  );
}
