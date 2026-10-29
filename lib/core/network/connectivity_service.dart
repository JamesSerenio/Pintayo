import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  final Connectivity connectivity;
  ConnectivityService(this.connectivity);
  Future<bool> get isConnected async =>
      !(await connectivity.checkConnectivity()).contains(
        ConnectivityResult.none,
      );
  Stream<bool> get changes => connectivity.onConnectivityChanged
      .map((events) => !events.contains(ConnectivityResult.none))
      .distinct();
}

final connectivityServiceProvider = Provider(
  (ref) => ConnectivityService(Connectivity()),
);
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isConnected;
  yield* service.changes;
});
