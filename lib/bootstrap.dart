import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/pintayo_app.dart';
import 'core/config/app_config.dart';
import 'features/notifications/data/fcm_service.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.environment();
  config.validate();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
    );
  }
  final fcm = FcmService(config);
  await fcm.initialize();
  runApp(
    ProviderScope(
      overrides: [fcmServiceProvider.overrideWithValue(fcm)],
      child: const PinTayoApp(),
    ),
  );
}
