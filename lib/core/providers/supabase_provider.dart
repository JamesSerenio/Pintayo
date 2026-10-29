import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

final configProvider = Provider<AppConfig>(
  (ref) => const AppConfig.environment(),
);
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
final devicePlatformProvider = Provider((ref) => defaultTargetPlatform.name);
