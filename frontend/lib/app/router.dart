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

/// Global guard, run before every navigation and whenever [status] changes.
///
/// Each status only reaches its own screens (design system 10.2):
/// signed out → Welcome, S03, S04 and S09; an open code request → S03, S04
/// and S09 (else S04); no name → S05; no PIN → S06; locked → S08 and S09.
/// An unlocked user leaving a sign-in step goes to S07, which moves on to
/// Home when there is nothing to offer; other sign-in screens send them Home.
/// The splash and the debug gallery are never redirected, and other routes
/// wait on the splash while the session is still loading.
///
/// After sign-in, a pending invite link should open the join screen
/// (PRD 8.1), and the lock should return to the route it covered.
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

  return switch (status.value) {
    null || AuthSignedOut() => only(signedOutPaths, welcome),
    AuthOtpPending() => only({signIn, code, forgotPin}, code),
    AuthNeedsName() => only({name}, name),
    AuthNeedsPin() => only({newPin}, newPin),
    AuthLocked() => only({lock, forgotPin}, lock),
    AuthUnlocked() when {code, name, newPin, forgotPin}.contains(path) => biometric,
    AuthUnlocked() when {welcome, signIn, lock}.contains(path) => const HomeRoute().location,
    AuthUnlocked() => null,
  };
}
