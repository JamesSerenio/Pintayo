import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pintayo/features/notifications/application/notification_controller.dart';
import 'package:pintayo/features/notifications/application/notification_navigation.dart';
import 'package:pintayo/features/notifications/data/device_registration_repository.dart';
import 'package:pintayo/features/notifications/data/fcm_service.dart';
import 'package:pintayo/features/notifications/data/notification_preferences.dart';
import 'notification_navigation_test.dart' show user, other, notification;

class FakeFcm implements FcmGateway {
  @override
  PushAvailability availability = PushAvailability.ready;
  final ids = StreamController<String>.broadcast(sync: true);
  final revoked = StreamController<String>.broadcast(sync: true);
  final messages = StreamController<RemoteMessage>.broadcast(sync: true);
  final taps = StreamController<RemoteMessage>.broadcast(sync: true);
  int registerCalls = 0, unregisterCalls = 0;
  bool allowed = true;
  String registration = 'test-only-installation-fid';
  RemoteMessage? launchMessage;
  @override
  Future<void> initialize() async {}
  @override
  Stream<String> get registrations => ids.stream;
  @override
  Stream<String> get invalidations => revoked.stream;
  @override
  Stream<RemoteMessage> get foregroundMessages => messages.stream;
  @override
  Stream<RemoteMessage> get openedMessages => taps.stream;
  @override
  Future<RemoteMessage?> initialMessage() async => launchMessage;
  @override
  Future<bool> hasPermission() async => allowed;
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<void> register() async {
    registerCalls++;
    ids.add(registration);
  }

  @override
  Future<void> unregister() async {
    unregisterCalls++;
    revoked.add(registration);
  }

  Future<void> dispose() async {
    await ids.close();
    await revoked.close();
    await messages.close();
    await taps.close();
  }
}

class FakeDevices implements DeviceRegistrations {
  @override
  String? currentUserId = user;
  final changes = StreamController<String?>.broadcast(sync: true);
  final saved = <(String, String)>[];
  int removals = 0;
  Completer<void>? delaySave;
  bool failSave = false;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<void> save({
    required String user,
    required String installation,
    required String registration,
  }) async {
    await delaySave?.future;
    if (failSave) throw StateError('Test registration failure');
    if (currentUserId != user) throw StateError('Account changed');
    saved.add((user, registration));
  }

  @override
  Future<void> remove(String installation, {String? registration}) async {
    removals++;
  }

  void account(String? id) {
    currentUserId = id;
    changes.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFcm fcm;
  late FakeDevices devices;
  late NotificationPreferences preferences;
  late NotificationController controller;
  late List<String> routes;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fcm = FakeFcm();
    devices = FakeDevices();
    preferences = NotificationPreferences();
    routes = [];
    controller = NotificationController(
      fcm,
      devices,
      preferences,
      NotificationNavigation(routes.add),
    );
  });
  tearDown(() async {
    controller.dispose();
    await devices.changes.close();
    await fcm.dispose();
  });
  test(
    'registration is saved only after opt-in; refresh and invalidation are reconciled',
    () async {
      await controller.initialize();
      expect(fcm.registerCalls, 0);
      expect(await controller.requestPermission(), isTrue);
      expect(devices.saved, [(user, 'test-only-installation-fid')]);
      fcm.ids.add('refreshed-test-fid');
      await controller.settled;
      expect(devices.saved.last, (user, 'refreshed-test-fid'));
      fcm.revoked.add('test-only-installation-fid');
      await controller.settled;
      expect(
        devices.removals,
        0,
        reason:
            'A delayed old invalidation must not remove a newer registration',
      );
      fcm.revoked.add('refreshed-test-fid');
      await controller.settled;
      expect(devices.removals, 1);
      expect(controller.enabled, isFalse);
    },
  );
  test(
    'explicit logout disassociates registration before the auth session ends',
    () async {
      await controller.initialize();
      await controller.requestPermission();
      await controller.unregister();
      expect(devices.removals, 1);
      expect(fcm.unregisterCalls, 1);
      expect(await preferences.boundOwner(), isNull);
      devices.account(null);
      await controller.settled;
      fcm.ids.add('late-test-fid');
      await controller.settled;
      expect(devices.saved, hasLength(1));
    },
  );
  test(
    'switching accounts invalidates the old FID and requires separate consent',
    () async {
      await controller.initialize();
      await controller.requestPermission();
      devices.account(other);
      await controller.settled;
      expect(fcm.unregisterCalls, 1);
      expect(controller.enabled, isFalse);
      fcm.ids.add('stale-test-fid');
      await controller.settled;
      expect(devices.saved, hasLength(1));
      expect(await controller.requestPermission(), isTrue);
      expect(devices.saved.last.$1, other);
    },
  );
  test(
    'account changes during a registration cannot save against the wrong user',
    () async {
      await controller.initialize();
      devices.delaySave = Completer<void>();
      final permission = controller.requestPermission();
      await Future<void>.delayed(Duration.zero);
      devices.account(other);
      devices.delaySave!.complete();
      await expectLater(permission, throwsA(isA<StateError>()));
      await controller.settled;
      expect(devices.saved, isEmpty);
    },
  );
  test('missing native configuration does not register or prompt', () async {
    fcm.availability = PushAvailability.unconfigured;
    await controller.initialize();
    expect(await controller.requestPermission(), isFalse);
    expect(devices.saved, isEmpty);
    expect(fcm.registerCalls, 0);
  });
  test(
    'foreground notification is one in-app notice, not a receipt or duplicate alert',
    () async {
      await controller.initialize();
      var updates = 0;
      controller.addListener(() {
        updates++;
      });
      fcm.messages.add(RemoteMessage(data: notification()));
      fcm.messages.add(RemoteMessage(data: notification()));
      expect(updates, 1);
      expect(controller.foreground, isNotNull);
      controller.openForeground();
      expect(routes.last, startsWith('/chat/'));
      expect(devices.saved, isEmpty);
    },
  );
  test(
    'terminated notification is deferred until its matching account signs in',
    () async {
      devices.currentUserId = null;
      fcm.launchMessage = RemoteMessage(data: notification());
      await controller.initialize();
      expect(routes.single, startsWith('/auth?next='));
      devices.account(user);
      await controller.settled;
      expect(routes.last, startsWith('/chat/'));
    },
  );
}
