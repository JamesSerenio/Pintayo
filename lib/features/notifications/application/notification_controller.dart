import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_registration_repository.dart';
import '../data/fcm_service.dart';
import '../data/notification_preferences.dart';
import 'notification_navigation.dart';

class NotificationController extends ChangeNotifier {
  final FcmGateway fcm;
  final DeviceRegistrations devices;
  final NotificationPreferences preferences;
  final NotificationNavigation navigation;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _foregroundEvents = {};
  Future<void> _operations = Future.value();
  Future<void>? _initialization;
  Completer<void>? _registration;
  String? _account, _lastRegistration;
  int _epoch = 0;
  bool _bound = false, _disposed = false, enabled = false;
  NotificationTarget? foreground;
  String? problem;

  NotificationController(
    this.fcm,
    this.devices,
    this.preferences,
    this.navigation,
  );
  String get statusText => fcm.availability != PushAvailability.ready
      ? 'Notifications aren’t set up on this app yet. Other features work normally.'
      : problem ??
            (enabled
                ? 'Notifications are enabled on this device.'
                : 'Notifications are off on this device.');
  Future<void> get settled => _operations;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final operation = _operations.then((_) async {
      if (!_disposed) await task();
    });
    _operations = operation.catchError((Object _) {
      problem = 'Couldn’t update notification settings. Please try again.';
      _notify();
    });
    return operation;
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await fcm.initialize();
    if (_disposed) return;
    _subscriptions.add(
      devices.accountChanges.listen((user) {
        _changeAccount(user).catchError((Object _) {});
      }),
    );
    if (fcm.availability == PushAvailability.ready) {
      _subscriptions.addAll([
        fcm.registrations.listen(_registered),
        fcm.invalidations.listen(_invalidated),
        fcm.foregroundMessages.listen(_foreground),
        fcm.openedMessages.listen(_opened),
      ]);
    }
    try {
      await _changeAccount(devices.currentUserId);
      if (fcm.availability == PushAvailability.ready) {
        final initial = await fcm.initialMessage();
        if (initial != null && !_disposed) _opened(initial);
      }
    } catch (_) {
      problem = 'Couldn’t update notification settings. Please try again.';
    }
    _notify();
  }

  Future<void> _changeAccount(String? user) {
    if (_bound && user == _account) return _operations;
    _bound = true;
    _account = user;
    final epoch = ++_epoch;
    _lastRegistration = null;
    enabled = false;
    foreground = null;
    problem = null;
    if (!navigation.accountChanged(user)) {
      problem = 'This notification belongs to another account.';
    }
    _notify();
    return _enqueue(() async {
      final previous = await preferences.boundOwner();
      if (previous != null && previous != user) {
        // Also handles expired/replaced auth sessions, when their JWT can no
        // longer delete a row: invalidate the native FID, then transfer binding.
        if (fcm.availability == PushAvailability.ready) await fcm.unregister();
        await preferences.bindOwner(null);
      }
      if (epoch != _epoch ||
          user == null ||
          fcm.availability != PushAvailability.ready) {
        return;
      }
      enabled = await preferences.enabled(user) && await fcm.hasPermission();
      if (enabled) await fcm.register();
      _notify();
    });
  }

  void _registered(String registration) {
    final user = _account, epoch = _epoch;
    if (user == null || !enabled) return;
    _enqueue(() async {
      if (epoch != _epoch || devices.currentUserId != user || !enabled) return;
      await devices.save(
        user: user,
        installation: await preferences.installation(),
        registration: registration,
      );
      if (epoch != _epoch) return;
      _lastRegistration = registration;
      await preferences.bindOwner(user);
      problem = null;
      if (_registration?.isCompleted == false) _registration!.complete();
      _notify();
    }).catchError((Object error) {
      if (_registration?.isCompleted == false) {
        _registration!.completeError(error);
      }
    });
  }

  void _invalidated(String registration) {
    if (registration != _lastRegistration) return;
    _lastRegistration = null;
    enabled = false;
    _enqueue(() async {
      await devices.remove(
        await preferences.installation(),
        registration: registration,
      );
    }).catchError((Object _) {});
    _notify();
  }

  Future<bool> requestPermission() async {
    await initialize();
    await _operations;
    final user = _account, epoch = _epoch;
    if (user == null || fcm.availability != PushAvailability.ready) {
      _notify();
      return false;
    }
    if (!await fcm.requestPermission()) {
      problem =
          'Notifications are not allowed yet. Check your device settings.';
      _notify();
      return false;
    }
    if (epoch != _epoch) return false;
    enabled = true;
    _registration = Completer<void>();
    try {
      await Future.wait<void>([
        fcm.register(),
        _registration!.future.timeout(const Duration(seconds: 20)),
      ], eagerError: true);
      if (epoch != _epoch) return false;
      await preferences.setEnabled(user, true);
      _notify();
      return true;
    } catch (_) {
      enabled = false;
      problem = 'Notifications could not be enabled. Please try again.';
      _notify();
      rethrow;
    }
  }

  Future<void> unregister() async {
    await initialize();
    final user = _account;
    ++_epoch;
    enabled = false;
    _lastRegistration = null;
    foreground = null;
    if (user != null) await preferences.setEnabled(user, false);
    await _enqueue(() async {
      await devices.remove(await preferences.installation());
      if (fcm.availability == PushAvailability.ready) await fcm.unregister();
      await preferences.bindOwner(null);
    });
    _notify();
  }

  void _foreground(RemoteMessage message) {
    final target = NotificationTarget.parse(message.data);
    if (target == null ||
        target.recipient != _account ||
        !_foregroundEvents.add(target.event)) {
      return;
    }
    if (_foregroundEvents.length > 100) {
      _foregroundEvents.remove(_foregroundEvents.first);
    }
    foreground = target;
    _notify();
  }

  void _opened(RemoteMessage message) {
    final target = NotificationTarget.parse(message.data);
    if (target == null) return;
    if (!navigation.open(target, _account)) {
      problem = 'This notification belongs to another account.';
      _notify();
    }
  }

  void openForeground() {
    final target = foreground;
    foreground = null;
    if (target != null) navigation.open(target, _account);
    _notify();
  }

  void dismissForeground() {
    foreground = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

final notificationControllerProvider = Provider((ref) {
  final controller = NotificationController(
    ref.watch(fcmServiceProvider),
    ref.watch(deviceRegistrationRepositoryProvider),
    ref.watch(notificationPreferencesProvider),
    ref.watch(notificationNavigationProvider),
  );
  ref.onDispose(controller.dispose);
  controller.initialize();
  return controller;
});
