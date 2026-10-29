import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// A fresh provider per map owns its HTTP client. flutter_map's built-in cache
// honors tile caching headers. Tests can supply a memory-only provider.
final tileProviderFactoryProvider = Provider<TileProvider Function()>(
  (ref) =>
      () => NetworkTileProvider(),
);
