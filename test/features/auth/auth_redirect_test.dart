import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/app/router/auth_redirect.dart';
import 'package:pintayo/core/config/app_config.dart';

void main() {
  test('return paths reject external URLs and auth redirect loops', () {
    expect(returnLocation('https://example.com'), '/map');
    expect(returnLocation('//example.com/chat'), '/map');
    expect(returnLocation('/onboarding?next=/onboarding'), '/map');
    expect(returnLocation('/chat/123'), '/chat/123');
  });
  test('login protects deep links and recovery outranks onboarding', () {
    expect(
      authDestination(
        configured: true,
        signedIn: false,
        recovering: false,
        onboarded: false,
        location: '/chat/abc',
      ),
      '/auth?next=%2Fchat%2Fabc',
    );
    expect(
      authDestination(
        configured: true,
        signedIn: true,
        recovering: true,
        onboarded: false,
        location: '/map',
      ),
      '/recovery',
    );
    expect(
      authDestination(
        configured: true,
        signedIn: true,
        recovering: false,
        onboarded: false,
        location: '/chat/abc',
      ),
      '/onboarding',
    );
    expect(
      authDestination(
        configured: true,
        signedIn: true,
        recovering: false,
        onboarded: true,
        location: '/friends',
      ),
      isNull,
    );
  });
  test(
    'configuration rejects partial credentials and battery-hostile intervals',
    () {
      expect(
        () => const AppConfig(
          supabaseUrl: 'https://example.com',
          supabaseKey: '',
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const AppConfig(
          supabaseUrl: '',
          supabaseKey: '',
          movingSeconds: 1,
        ).validate(),
        throwsArgumentError,
      );
    },
  );
}
