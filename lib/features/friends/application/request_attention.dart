import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/supabase_provider.dart';

/// Viewing a request clears attention only; accepting it is a separate action.
class RequestAttention extends ChangeNotifier {
  final String user;
  final Map<String, Set<String>> _seen = {};
  bool _disposed = false;
  late final Future<void> ready;
  RequestAttention(this.user) {
    ready = _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    for (final area in ['friends', 'requests']) {
      _seen
          .putIfAbsent(area, () => {})
          .addAll(prefs.getStringList('request_attention:$user:$area') ?? []);
    }
    notifyListeners();
  }

  int count(String area, Iterable<String> ids) =>
      ids.where((id) => !(_seen[area]?.contains(id) ?? false)).length;
  Future<void> mark(String area, Iterable<String> ids) async {
    if (_disposed) return;
    final values = _seen.putIfAbsent(area, () => {});
    final fresh = ids.where((id) => !values.contains(id)).toList();
    if (fresh.isEmpty) return;
    values.addAll(fresh);
    if (!_disposed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('request_attention:$user:$area', values.toList());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final requestAttentionProvider = Provider.autoDispose((ref) {
  final state = RequestAttention(
    ref.watch(supabaseProvider).auth.currentUser!.id,
  );
  ref.onDispose(state.dispose);
  return state;
});
