import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/features/location_sharing/data/models/shared_location.dart';

SharedLocation fix(DateTime time) => SharedLocation(
  owner: 'friend',
  latitude: 14,
  longitude: 121,
  accuracy: 25,
  fixedAt: time,
);
void main() {
  test('old and duplicate coordinates cannot replace newer fixes', () {
    final newer = fix(DateTime.now());
    expect(
      fix(newer.fixedAt.subtract(const Duration(seconds: 15))).newerThan(newer),
      isFalse,
    );
    expect(fix(newer.fixedAt).newerThan(newer), isFalse);
    expect(
      fix(newer.fixedAt.add(const Duration(seconds: 15))).newerThan(newer),
      isTrue,
    );
  });
  test('old fixes are last known, never fresh', () {
    expect(
      fix(DateTime.now().subtract(const Duration(minutes: 5))).fresh,
      isFalse,
    );
  });
}
