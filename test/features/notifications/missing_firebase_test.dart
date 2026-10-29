import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pintayo/app/pintayo_app.dart';
import 'package:pintayo/core/config/app_config.dart';
import 'package:pintayo/core/providers/supabase_provider.dart';
import 'package:pintayo/features/notifications/data/fcm_service.dart';

const config = AppConfig(
  supabaseUrl: 'https://fixture.supabase.co',
  supabaseKey: 'sb_publishable_test_only_fixture',
  firebaseProjectId: 'pintayo',
  firebaseMessagingSenderId: '759625922563',
  pushEnabled: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native configuration failure is contained by the actual FCM adapter',
    () async {
      final fcm = FcmService(config);
      await expectLater(fcm.initialize(), completes);
      expect(fcm.availability, PushAvailability.unconfigured);
    },
  );
  testWidgets('missing Firebase configuration leaves Supabase sign-in usable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        config.supabaseUrl,
        config.supabaseKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(config),
          supabaseProvider.overrideWithValue(client),
        ],
        child: const PinTayoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(client.dispose);
  });
}
