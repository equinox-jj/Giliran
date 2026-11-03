import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/domain/entities/auth_status.dart';
import '../features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'routes.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Bridges the session into a Listenable so the guard re-runs whenever it
  // changes (sign-in, unlock, logout, session expired).
  final authStatus = ValueNotifier(ref.read(authSessionControllerProvider));

  ref.listen(
    authSessionControllerProvider,
    (_, next) => authStatus.value = next,
  );

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: $appRoutes,
    initialLocation: const SplashRoute().location,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authStatus,
    redirect: (context, state) => authRedirect(authStatus.value, state.uri),
  );

  ref.onDispose(() {
    router.dispose();
    authStatus.dispose();
  });

  return router;
}

String? authRedirect(AsyncValue<AuthStatus> status, Uri uri) {
  final path = uri.path;
  if (path == const SplashRoute().location || path == const GalleryRoute().location) {
    return null;
  }

  final welcome = const WelcomeRoute().location;
  final signIn = const SignInRoute().location;
  final code = const VerifyOtpRoute().location;
  final name = const FillNameRoute().location;
  final newPin = const SetPinRoute().location;
  final biometric = const BiometricRoute().location;
  final lock = const LockRoute().location;
  final forgotPin = const ForgotPinRoute().location;

  final signedOutPaths = {welcome, signIn, code, forgotPin};
  if (!status.hasValue && !status.hasError) {
    return signedOutPaths.contains(path) ? null : const SplashRoute().location;
  }

  String? only(Set<String> allowed, String fallback) => allowed.contains(path) ? null : fallback;

  // Sign-in steps are never worth returning to after the lock.
  final authPaths = {...signedOutPaths, name, newPin, biometric, lock};

  return switch (status.value) {
    null || AuthSignedOut() => only(signedOutPaths, welcome),
    AuthOtpPending() => only({signIn, code, forgotPin}, code),
    AuthNeedsName() => only({name}, name),
    AuthNeedsPin() => only({newPin}, newPin),
    AuthLocked() => only(
      {lock, forgotPin},
      LockRoute(from: authPaths.contains(path) ? null : uri.toString()).location,
    ),
    AuthUnlocked() when {code, name, newPin, forgotPin}.contains(path) => biometric,
    AuthUnlocked() when path == lock => lockReturnTo(uri.queryParameters['from']),
    AuthUnlocked() when {welcome, signIn}.contains(path) => const HomeRoute().location,
    AuthUnlocked() => null,
  };
}

/// Where an unlocked lock screen goes: [from] when it is an app path (not an
/// outside URL, not the lock itself), otherwise Home.
@visibleForTesting
String lockReturnTo(String? from) {
  final home = const HomeRoute().location;
  if (from == null) return home;

  final target = Uri.tryParse(from);
  if (target == null || target.hasScheme || target.hasAuthority || !target.path.startsWith('/')) {
    return home;
  }

  return target.path == const LockRoute().location ? home : from;
}
