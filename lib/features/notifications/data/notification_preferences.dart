import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class NotificationPreferences {
  Future<SharedPreferences> get _store => SharedPreferences.getInstance();
  Future<String> installation() async {
    final store = await _store;
    final value = store.getString('installation') ?? const Uuid().v4();
    await store.setString('installation', value);
    return value;
  }

  Future<bool> enabled(String user) async =>
      (await _store).getBool('push_enabled:$user') ?? false;
  Future<void> setEnabled(String user, bool value) async =>
      (await _store).setBool('push_enabled:$user', value);
  Future<String?> boundOwner() async =>
      (await _store).getString('push_bound_owner');
  Future<void> bindOwner(String? user) async {
    final store = await _store;
    if (user == null) {
      await store.remove('push_bound_owner');
    } else {
      await store.setString('push_bound_owner', user);
    }
  }
}

final notificationPreferencesProvider = Provider(
  (ref) => NotificationPreferences(),
);
