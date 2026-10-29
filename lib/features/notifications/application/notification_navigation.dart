import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/router/app_router.dart';

class NotificationTarget {
  final String event, recipient, route;
  const NotificationTarget(this.event, this.recipient, this.route);
  static NotificationTarget? parse(Map<String, dynamic> data) {
    bool valid(dynamic value) =>
        value is String && Uuid.isValidUUID(fromString: value);
    if (!valid(data['event_id']) || !valid(data['recipient_id'])) return null;
    if (data['kind'] == 'friend_request') {
      return NotificationTarget(
        data['event_id'],
        data['recipient_id'],
        '/friends?requests=true',
      );
    }
    if (data['kind'] == 'message' && valid(data['conversation_id'])) {
      return NotificationTarget(
        data['event_id'],
        data['recipient_id'],
        '/chat/${data['conversation_id']}',
      );
    }
    return null;
  }
}

class NotificationNavigation {
  final void Function(String) navigate;
  NotificationTarget? _pending;
  final Set<String> _opened = {};
  NotificationNavigation(this.navigate);
  bool open(NotificationTarget target, String? user) {
    if (_opened.contains(target.event)) return true;
    if (user == null) {
      _pending = target;
      navigate(
        '/auth?next=${Uri.encodeComponent(target.route)}&notificationRecipient=${target.recipient}',
      );
      return true;
    }
    if (target.recipient != user) {
      _pending = null;
      return false;
    }
    _pending = null;
    _opened.add(target.event);
    if (_opened.length > 100) _opened.remove(_opened.first);
    navigate(target.route);
    return true;
  }

  bool accountChanged(String? user) =>
      _pending == null || user == null ? true : open(_pending!, user);
}

final notificationNavigationProvider = Provider(
  (ref) =>
      NotificationNavigation((route) => ref.read(appRouterProvider).go(route)),
);
