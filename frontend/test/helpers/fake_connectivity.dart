import 'package:giliran/core/network/connectivity_controller.dart';

/// Reports a fixed connection state instead of asking the platform.
class FakeConnectivityController(final bool online) extends ConnectivityController {
  @override
  Stream<bool> build() => Stream.value(online);
}
