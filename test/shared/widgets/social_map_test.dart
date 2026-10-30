import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pintayo/features/map/application/map_controller.dart';
import 'package:pintayo/features/location_sharing/data/models/shared_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pintayo/features/map/presentation/pages/map_page.dart';
import 'package:pintayo/features/chat/presentation/pages/chats_page.dart';
import 'package:pintayo/features/chat/data/chat_repository.dart';
import 'package:pintayo/features/friends/data/friends_repository.dart';
import 'package:pintayo/features/profile/data/models/profile.dart';
import '../../support/empty_app_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('map automatically frames newly shared locations', (
    tester,
  ) async {
    await tester.pumpWidget(emptyAppFixture(const Scaffold(body: MapPage())));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(MapPage));
    final container = ProviderScope.containerOf(element);
    final state = container.read(mapStateProvider);
    final now = DateTime.now();
    state.locations = {
      'a': SharedLocation(
        owner: 'a',
        latitude: 8.31,
        longitude: 124.86,
        accuracy: 10,
        fixedAt: now,
      ),
      'b': SharedLocation(
        owner: 'b',
        latitude: 8.32,
        longitude: 124.87,
        accuracy: 10,
        fixedAt: now,
      ),
    };
    await state.selectCircle(null);
    await tester.pumpAndSettle();
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(camera.center.latitude, inInclusiveRange(8.30, 8.33));
    expect(camera.center.longitude, inInclusiveRange(124.85, 124.88));
    expect(camera.zoom, greaterThan(5));
    expect(camera.zoom, lessThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'sharing card is hidden until the map sharing control is tapped',
    (tester) async {
      await tester.pumpWidget(emptyAppFixture(const Scaffold(body: MapPage())));
      await tester.pumpAndSettle();
      expect(find.text('Your location is private'), findsNothing);
      await tester.tap(find.byTooltip('Location sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Your location is private'), findsOneWidget);
      expect(find.text('Choose who to share with'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'chat list shows active friends and distinguishes unread previews',
    (tester) async {
      const person = Profile(
        id: 'friend',
        username: 'friend',
        displayName: 'Test Friend',
      );
      await tester.pumpWidget(
        emptyAppFixture(
          const Scaffold(body: ChatsPage()),
          friends: [
            const Friendship('request', person, accepted: true, incoming: true),
          ],
          online: {'friend'},
          chats: [
            Conversation('chat', 'Unread hello', person, 3, DateTime.now()),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Active now'), findsOneWidget);
      expect(find.text('Test Friend'), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      final preview = tester.widget<Text>(find.text('Unread hello'));
      expect(preview.style?.fontWeight, FontWeight.w700);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
