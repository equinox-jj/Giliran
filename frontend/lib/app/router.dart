import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/domain/entities/auth_status.dart';
import '../features/auth/presentation/shared/controllers/auth_session_controller.dart';
import '../core/network/api_endpoints.dart';
import '../core/services/share_service.dart';
import 'deep_link_controller.dart';
import 'routes.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Bridges the session into a Listenable so the guard re-runs whenever it
  // changes (sign-in, unlock, logout, session expired).
  final authStatus = ValueNotifier(ref.read(authSessionControllerProvider));
  final deepLinks = ref.read(deepLinkControllerProvider);
  final share = ref.read(shareServiceProvider);

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
    redirect: (context, state) => _redirect(authStatus.value, state.uri, deepLinks, share),
  );

  ref.onDispose(() {
    router.dispose();
    authStatus.dispose();
  });

  return router;
}

/// [authRedirect] plus its side effects: an invite or claim link the guard
/// turns away is remembered in [deepLinks], and the pending link is
/// consumed when the guard sends the user to it. A draw verification link
/// (`/v/:code`) opens the public page in the browser until Bukti Kocok
/// lands in Phase 5, and the app goes Home.
String? _redirect(AsyncValue<AuthStatus> status, Uri uri, DeepLinkController deepLinks, ShareService share) {
  final segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == 'v') {
    unawaited(share.openUrl(ApiEndpoints.verifyPage(segments.last)));
    return authRedirect(status, Uri.parse(const HomeRoute().location)) ?? const HomeRoute().location;
  }
  final target = authRedirect(status, uri, pending: deepLinks.pending);
  if (target == null) return null;
  if (DeepLinkController.isResumable(uri.path)) {
    // App links can arrive as the full https URL; keep the in-app location.
    deepLinks.remember(Uri(path: uri.path, query: uri.hasQuery ? uri.query : null).toString());
  } else if (target == deepLinks.pending) {
    deepLinks.consumePending();
  }
  return target;
}

/// The global guard. [pending] is an invite or claim link opened before the
/// session was unlocked; an unlocked session goes there instead of its
/// usual destination (except the splash, the gallery and the biometric
/// opt-in, which comes first).
String? authRedirect(AsyncValue<AuthStatus> status, Uri uri, {String? pending}) {
  final target = _guard(status, uri);
  if (pending != null && status.value is AuthUnlocked) {
    final destination = Uri.parse(target ?? uri.toString()).path;
    final stay = {
      const SplashRoute().location,
      const GalleryRoute().location,
      const BiometricRoute().location,
      Uri.parse(pending).path,
    };
    if (!stay.contains(destination)) return pending;
  }
  return target;
}

String? _guard(AsyncValue<AuthStatus> status, Uri uri) {
  final path = uri.path;
  final invite = path.startsWith('/j/');
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
    null || AuthSignedOut() => only(signedOutPaths, invite ? const WelcomeRoute(invited: true).location : welcome),
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
