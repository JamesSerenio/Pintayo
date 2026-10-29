class Profile {
  final String id, username, displayName, firstName, lastName;
  final String? avatarPath;
  final DateTime? lastActive;
  final bool hideActivity, onboarded;
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.avatarPath,
    this.lastActive,
    this.hideActivity = false,
    this.onboarded = false,
  });
  factory Profile.fromJson(Map<String, dynamic> row) => Profile(
    id: row['id'],
    username: row['username'] ?? '',
    displayName: row['display_name'] ?? 'PinTayo member',
    firstName: row['first_name'] ?? '',
    lastName: row['last_name'] ?? '',
    avatarPath: row['avatar_path'],
    lastActive: DateTime.tryParse(row['last_active'] ?? ''),
    hideActivity: row['hide_activity'] ?? true,
    onboarded: row['onboarded'] ?? false,
  );
}
