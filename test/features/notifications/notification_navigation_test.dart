import 'package:flutter_test/flutter_test.dart';
import 'package:pintayo/features/notifications/application/notification_navigation.dart';

const user = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
const event = '10000000-0000-4000-8000-000000000001';
const chat = '20000000-0000-4000-8000-000000000001';
Map<String, dynamic> notification({String kind = 'message'}) => {
  'kind': kind,
  'event_id': event,
  'recipient_id': user,
  'conversation_id': chat,
};
void main() {
  test(
    'terminated tap keeps its route through login and deduplicates open events',
    () {
      final routes = <String>[];
      final navigation = NotificationNavigation(routes.add);
      final target = NotificationTarget.parse(notification())!;
      expect(navigation.open(target, null), isTrue);
      expect(routes.single, contains('/auth?next='));
      expect(navigation.accountChanged(user), isTrue);
      expect(routes.last, '/chat/$chat');
      navigation.open(target, user);
      expect(routes.length, 2);
    },
  );
  test('another account cannot navigate to a notification target', () {
    final routes = <String>[];
    final navigation = NotificationNavigation(routes.add);
    expect(
      navigation.open(NotificationTarget.parse(notification())!, other),
      isFalse,
    );
    expect(routes, isEmpty);
  });
  test(
    'friend requests open the requests tab and malformed targets are rejected',
    () {
      expect(
        NotificationTarget.parse(notification(kind: 'friend_request'))!.route,
        '/friends?requests=true',
      );
      expect(
        NotificationTarget.parse({
          ...notification(),
          'conversation_id': 'https://example.com',
        }),
        isNull,
      );
      expect(
        NotificationTarget.parse({...notification(), 'recipient_id': null}),
        isNull,
      );
      expect(NotificationTarget.parse(notification(kind: 'location')), isNull);
    },
  );
}
