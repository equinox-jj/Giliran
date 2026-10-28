import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'routes.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    routes: $appRoutes,
    initialLocation: const HomeRoute().location,
    debugLogDiagnostics: kDebugMode,
    redirect: _authRedirect,
  );
  ref.onDispose(router.dispose);
  return router;
}

/// Global guard, run before every navigation.
///
/// Becomes the auth guard once auth state exists: signed-out users go to
/// [SignInRoute], and after sign-in a pending invite link opens the join
/// screen (PRD 8.1). Pass the auth state as `refreshListenable` so the guard
/// re-runs when it changes.
String? _authRedirect(BuildContext context, GoRouterState state) => null;
