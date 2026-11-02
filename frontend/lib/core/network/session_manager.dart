import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_manager.g.dart';

/// Broadcasts a "session expired" signal from the network layer to the router
/// without coupling networking to navigation.
class SessionManager {
  final _controller = StreamController<void>.broadcast();

  /// Emits when refresh fails and the user must sign in again.
  Stream<void> get onSessionExpired => _controller.stream;

  /// Signals that the session has expired.
  void notifyExpired() {
    if (!_controller.isClosed) _controller.add(null);
  }

  /// Closes the underlying stream.
  void dispose() => _controller.close();
}

@Riverpod(keepAlive: true)
SessionManager sessionManager(Ref ref) {
  final manager = SessionManager();
  ref.onDispose(manager.dispose);
  return manager;
}
