import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class AuthController extends ChangeNotifier {
  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  bool recovering = false;
  AuthController(this.client) {
    _subscription = client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) recovering = true;
      if (event.event == AuthChangeEvent.signedOut) recovering = false;
      notifyListeners();
    });
  }
  String? get userId => client.auth.currentUser?.id;
  Future<void> login(String email, String password) async =>
      client.auth.signInWithPassword(email: email.trim(), password: password);
  Future<void> register(String email, String password) async =>
      client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'pintayo://app/auth',
      );
  Future<void> reset(String email) => client.auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: 'pintayo://app/recovery',
  );
  Future<void> recover(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    recovering = false;
    notifyListeners();
  }

  Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authControllerProvider = Provider((ref) {
  final controller = AuthController(ref.watch(supabaseProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
