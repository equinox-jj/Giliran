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
/// Signed-out users (including an open code request or an unfinished
/// onboarding) only reach Welcome and sign-in; signed-in users skip them for
/// Home. The splash and the debug gallery are never redirected, and other
/// routes wait on the splash while the session is still loading.
///
/// Until their routes exist, `locked` opens Home instead of `/lock` (S08),
/// and `otpPending`, `needsName` and `needsPin` go to Welcome instead of
/// S04, S05 and S06. After sign-in, a pending invite link should open the
/// join screen (PRD 8.1).
String? authRedirect(AsyncValue<AuthStatus> status, Uri uri) {
  final path = uri.path;
  if (path == const SplashRoute().location || path == const GalleryRoute().location) {
    return null;
  }

  final isPublic = path == const WelcomeRoute().location || path == const SignInRoute().location;
  if (!status.hasValue && !status.hasError) {
    return isPublic ? null : const SplashRoute().location;
  }

  final signedIn = switch (status.value) {
    AuthLocked() || AuthUnlocked() => true,
    _ => false,
  };
  if (!signedIn) return isPublic ? null : const WelcomeRoute().location;
  return isPublic ? const HomeRoute().location : null;
}
