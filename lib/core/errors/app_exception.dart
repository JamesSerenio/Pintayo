import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

String readableError(Object error) {
  if (error is AppException) return error.message;
  if (error is AuthException) return error.message;
  if (error is PostgrestException && error.code == '23505') {
    return 'That username or invitation is already in use.';
  }
  if (error is PostgrestException && error.code == 'P0001') {
    return error.message;
  }
  return 'Something went wrong. Check your connection and try again.';
}
