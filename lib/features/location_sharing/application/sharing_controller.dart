import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/location_tracker.dart';
import '../data/sharing_repository.dart';

final locationTrackerProvider = Provider.autoDispose((ref) {
  final tracker = LocationTracker(
    ref.watch(sharingRepositoryProvider),
    ref.watch(configProvider),
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});

class SharingController extends ChangeNotifier {
  final SharingRepository repository;
  final LocationTracker tracker;
  SharingSession? session;
  bool checked = false;
  String? error;
  bool busy = false, _disposed = false;
  Timer? _expiration;
  SharingController(this.repository, this.tracker) {
    _initialize().catchError((Object _) {
      error = 'Couldn’t check sharing. Connect and try again.';
      _notify();
    });
  }
  Future<void> _initialize() async {
    await refresh();
    if (!_disposed) {
      try {
        await tracker.restore(
          publish: session?.state == 'active' && session?.expired == false,
        );
      } catch (_) {
        error =
            'Location unavailable. Check GPS and permissions. You can still chat.';
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    session = await repository.session();
    checked = true;
    _expiration?.cancel();
    if (session?.expiresAt != null) {
      final remaining = session!.expiresAt!.difference(DateTime.now());
      if (remaining.isNegative) {
        await tracker.stop();
        session = null;
      } else {
        _expiration = Timer(remaining, () async {
          await tracker.stop();
          session = null;
          _notify();
        });
      }
    }
    _notify();
  }

  Future<void> start(
    List<String> friends,
    List<String> circles,
    int minutes,
  ) async {
    busy = true;
    _notify();
    try {
      // Permission prompt follows the user's explicit start action.
      await tracker.enable(background: true);
      await repository.start(friends, circles, minutes);
      tracker.sharing = true;
      await tracker.enable(background: true);
      await refresh();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> change(String state) async {
    if (state != 'active') await tracker.stop();
    try {
      await repository.setState(state);
      error = null;
    } catch (_) {
      error =
          'Updates stopped on this device. Reconnect and retry to confirm access is revoked.';
      _notify();
      rethrow;
    }
    if (state == 'active') {
      tracker.sharing = true;
      await tracker.enable(background: true);
    } else {
      await tracker.stop();
    }
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiration?.cancel();
    super.dispose();
  }
}

final sharingControllerProvider = Provider.autoDispose((ref) {
  final controller = SharingController(
    ref.watch(sharingRepositoryProvider),
    ref.watch(locationTrackerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
