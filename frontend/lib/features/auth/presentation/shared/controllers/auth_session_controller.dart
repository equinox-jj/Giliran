import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/session_manager.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/auth_status.dart';
import '../../../domain/usecases/logout_usecase.dart';
import '../../../domain/usecases/resolve_auth_status_usecase.dart';
import '../../../domain/usecases/should_lock_on_resume_usecase.dart';

part 'auth_session_controller.g.dart';

/// The app-wide [AuthStatus]. The splash waits on it, the router guard
/// redirects from it, and the sign-in, PIN and lock controllers move it on.
///
/// A failed read surfaces as an `AsyncError` holding the [Failure]; the guard
/// treats it as signed out.
@Riverpod(keepAlive: true)
class AuthSessionController() extends _$AuthSessionController {
  @override
  Future<AuthStatus> build() async {
    // RefreshInterceptor has already cleared the tokens when this fires.
    final expired = ref
        .watch(sessionManagerProvider)
        .onSessionExpired
        .listen(
          (_) => state = const AsyncData(AuthStatus.signedOut(expired: true)),
        );

    ref.onDispose(expired.cancel);

    return _resolve(unlocked: false);
  }

  /// Re-reads the session after sign-in, setting the PIN or the name.
  /// [unlocked] skips the lock screen when the user just proved the PIN.
  /// Keeps the current value while loading so the guard does not flicker.
  Future<void> refresh({bool unlocked = false}) async {
    final next = await AsyncValue.guard(() => _resolve(unlocked: unlocked));
    if (ref.mounted) state = next;
  }

  void unlock() {
    if (state.value case AuthLocked(:final user)) {
      state = AsyncData(AuthStatus.unlocked(user: user));
    }
  }

  /// Locks an open session again, such as on resume after five minutes in
  /// the background (FR-AUTH-03).
  void lock() {
    if (state.value case AuthUnlocked(:final user)) {
      state = AsyncData(AuthStatus.locked(user: user));
    }
  }

  /// Locks an open session when the app comes back after [hiddenAt] and the
  /// background time reached the auto-lock limit. [now] defaults to the
  /// clock.
  Future<void> lockIfIdle(DateTime hiddenAt, {DateTime? now}) async {
    if (state.value is! AuthUnlocked) return;
    final result = await ref.read(shouldLockOnResumeUseCaseProvider)((
      hiddenAt: hiddenAt,
      now: now ?? DateTime.now(),
    ));
    if (!ref.mounted) return;
    if (result case Right(value: true)) lock();
  }

  Future<Failure?> logout() async {
    final result = await ref.read(logoutUseCaseProvider)(const NoParams());
    if (ref.mounted) state = const AsyncData(AuthStatus.signedOut());

    return result.getLeft().toNullable();
  }

  Future<AuthStatus> _resolve({required bool unlocked}) async {
    final result = await ref.read(resolveAuthStatusUseCaseProvider)((
      unlocked: unlocked,
    ));

    return result.fold((failure) => throw failure, (status) => status);
  }
}
