import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import 'sharing_repository.dart';

/// Native Geolocator service owns GPS. Publication is throttled; no timer
/// substitutes for Android foreground service or iOS background location.
class LocationTracker extends ChangeNotifier {
  final SharingRepository repository;
  final AppConfig config;
  StreamSubscription<Position>? _stream;
  DateTime? _lastSent;
  Position? _lastPublished;
  Position? position;
  String? problem;
  bool sharing = false, _disposed = false, _publishing = false;
  LocationTracker(this.repository, this.config);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore({required bool publish}) async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      if (publish) {
        problem =
            'Location permission is off. Stop sharing to hide your last known position.';
        _notify();
      }
      return;
    }
    sharing = publish;
    await enable(background: publish, requestPermission: false);
  }

  Future<void> enable({
    bool background = false,
    bool requestPermission = true,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException(
        'Turn on device location services, then try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AppException(
        'Location access is off. You can still chat. Enable it in Settings when ready.',
      );
    }
    if (background &&
        requestPermission &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        problem =
            'Background access is off. Updates may stop when you leave PinTayo.';
      }
    }
    await _stream?.cancel();
    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: Duration(seconds: config.movingSeconds),
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'PinTayo location sharing',
                notificationText:
                    'Sharing with your selected people. Open PinTayo to pause or stop.',
                enableWakeLock: true,
                setOngoing: true,
                notificationChannelName: 'PinTayo location sharing',
                notificationIcon: AndroidResource(
                  name: 'ic_pintayo_notification',
                ),
              )
            : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        allowBackgroundLocationUpdates: background,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: background,
      );
    }
    _stream = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object _) {
        problem = 'Location unavailable. Check permissions and GPS.';
        _notify();
      },
    );
    await _onPosition(
      await Geolocator.getCurrentPosition(locationSettings: settings),
    );
  }

  Future<void> _onPosition(Position fix) async {
    if (_disposed) return;
    position = fix;
    _notify();
    if (!sharing ||
        _publishing ||
        !fix.latitude.isFinite ||
        !fix.longitude.isFinite ||
        fix.accuracy > 1000) {
      return;
    }
    final moving =
        _lastPublished == null ||
        Geolocator.distanceBetween(
              _lastPublished!.latitude,
              _lastPublished!.longitude,
              fix.latitude,
              fix.longitude,
            ) >
            15;
    if (_lastSent != null &&
        DateTime.now().difference(_lastSent!).inSeconds <
            (moving ? config.movingSeconds : config.stationarySeconds)) {
      return;
    }
    _publishing = true;
    try {
      await repository.publish(
        fix.latitude,
        fix.longitude,
        fix.accuracy,
        fix.timestamp,
      );
      _lastSent = DateTime.now();
      _lastPublished = fix;
      problem = null;
    } catch (_) {
      problem =
          'Location could not update. Check your connection and sharing session.';
    }
    _publishing = false;
    _notify();
  }

  Future<void> refreshPosition() async {
    if (_stream == null) {
      await enable(background: sharing);
      return;
    }
    await _onPosition(
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 25),
        ),
      ),
    );
  }

  Future<void> stop() async {
    sharing = false;
    await _stream?.cancel();
    _stream = null;
    _lastSent = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stream?.cancel();
    super.dispose();
  }
}
