class SharedLocation {
  final String owner;
  final double latitude, longitude, accuracy;
  final DateTime fixedAt;
  const SharedLocation({
    required this.owner,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.fixedAt,
  });
  bool get fresh => DateTime.now().difference(fixedAt).inSeconds < 45;
  bool newerThan(SharedLocation? previous) =>
      previous == null || fixedAt.isAfter(previous.fixedAt);
  factory SharedLocation.fromJson(Map<String, dynamic> row) => SharedLocation(
    owner: row['owner'],
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    accuracy: (row['accuracy'] as num).toDouble(),
    fixedAt: DateTime.parse(row['fixed_at']),
  );
}
