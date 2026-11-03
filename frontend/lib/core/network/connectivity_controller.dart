import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_controller.g.dart';

/// Whether the device has a network connection, `true` when online.
///
/// Drives the offline banner and disables server-only actions. A network
/// interface being up doesn't prove the API is reachable, so request failures
/// are still handled on their own.
@Riverpod(keepAlive: true)
class ConnectivityController() extends _$ConnectivityController {
  @override
  Stream<bool> build() async* {
    final connectivity = Connectivity();
    yield _isOnline(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  static bool _isOnline(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);
}
