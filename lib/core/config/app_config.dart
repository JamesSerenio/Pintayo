class AppConfig {
  final String supabaseUrl, supabaseKey, tileUrl, appId, inviteBase;
  final String supabaseProjectRef, firebaseProjectId, firebaseMessagingSenderId;
  final bool pushEnabled;
  final int movingSeconds, stationarySeconds;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    this.supabaseProjectRef = '',
    this.firebaseProjectId = '',
    this.firebaseMessagingSenderId = '',
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.appId = 'com.pintayo.mobile',
    this.inviteBase = 'pintayo://app',
    this.pushEnabled = false,
    this.movingSeconds = 15,
    this.stationarySeconds = 60,
  });

  // Public client credentials only; server secrets never belong in the app.
  // Dart defines override these defaults for other environments.
  const AppConfig.environment()
    : supabaseUrl = const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://djqnavpwrkgcylwvdoxa.supabase.co',
      ),
      supabaseKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: 'sb_publishable_cZaIiCnrjX2qfzLU5YtSnQ_C8zCT0kc',
        ),
      ),
      supabaseProjectRef = const String.fromEnvironment('SUPABASE_PROJECT_REF'),
      firebaseProjectId = const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: 'pintayo',
      ),
      firebaseMessagingSenderId = const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '759625922563',
      ),
      tileUrl = const String.fromEnvironment(
        'TILE_URL',
        defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      appId = const String.fromEnvironment(
        'APP_ID',
        defaultValue: 'com.example.pintayo',
      ),
      inviteBase = const String.fromEnvironment(
        'INVITE_BASE',
        defaultValue: 'pintayo://app',
      ),
      pushEnabled = const bool.fromEnvironment('ENABLE_PUSH'),
      movingSeconds = const int.fromEnvironment(
        'MOVING_SECONDS',
        defaultValue: 15,
      ),
      stationarySeconds = const int.fromEnvironment(
        'STATIONARY_SECONDS',
        defaultValue: 60,
      );

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  void validate() {
    if (supabaseUrl.isEmpty != supabaseKey.isEmpty) {
      throw ArgumentError(
        'Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (isConfigured &&
        (uri?.hasAuthority != true ||
            !['http', 'https'].contains(uri?.scheme))) {
      throw ArgumentError('Invalid Supabase URL.');
    }
    if (isConfigured && supabaseKey.startsWith('sb_secret_')) {
      throw ArgumentError(
        'Use a publishable client key, never a server secret.',
      );
    }
    if (isConfigured &&
        supabaseProjectRef.isNotEmpty &&
        uri!.host.endsWith('.supabase.co') &&
        uri.host.split('.').first != supabaseProjectRef) {
      throw ArgumentError('Supabase URL does not match SUPABASE_PROJECT_REF.');
    }
    if (firebaseMessagingSenderId.isNotEmpty &&
        !RegExp(r'^\d+$').hasMatch(firebaseMessagingSenderId)) {
      throw ArgumentError('Invalid Firebase messaging sender ID.');
    }
    if (movingSeconds < 10 || stationarySeconds < movingSeconds) {
      throw ArgumentError('Invalid tracking intervals.');
    }
  }
}
