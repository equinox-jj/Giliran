import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/group/presentation/pages/groups_page.dart';
import '../features/history/presentation/pages/activity_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../shared/widgets/widgets.dart';
import 'component_gallery_page.dart';

part 'routes.g.dart';

/// Main tabs. Branch order must match [AppNavDestination.main].
@TypedStatefulShellRoute<AppShellRoute>(
  branches: [
    TypedStatefulShellBranch<HomeBranch>(
      routes: [
        TypedGoRoute<HomeRoute>(
          name: 'home',
          path: '/home',
        ),
      ],
    ),
    TypedStatefulShellBranch<GroupsBranch>(
      routes: [
        TypedGoRoute<GroupsRoute>(
          name: 'groups',
          path: '/groups',
        ),
      ],
    ),
    TypedStatefulShellBranch<ActivityBranch>(
      routes: [
        TypedGoRoute<ActivityRoute>(
          name: 'activity',
          path: '/activity',
        ),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranch>(
      routes: [
        TypedGoRoute<ProfileRoute>(
          name: 'profile',
          path: '/profile',
        ),
      ],
    ),
  ],
)
class AppShellRoute extends StatefulShellRouteData {
  const AppShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return AppNavShell(
      body: navigationShell,
      selectedIndex: navigationShell.currentIndex,
      // Re-tapping the active tab pops it back to its root.
      onSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
    );
  }
}

class HomeBranch extends StatefulShellBranchData {
  const HomeBranch();
}

class GroupsBranch extends StatefulShellBranchData {
  const GroupsBranch();
}

class ActivityBranch extends StatefulShellBranchData {
  const ActivityBranch();
}

class ProfileBranch extends StatefulShellBranchData {
  const ProfileBranch();
}

class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

class GroupsRoute extends GoRouteData with $GroupsRoute {
  const GroupsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const GroupsPage();
}

class ActivityRoute extends GoRouteData with $ActivityRoute {
  const ActivityRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ActivityPage();
}

class ProfileRoute extends GoRouteData with $ProfileRoute {
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfilePage();
}

/// S01 launch gate. Until auth state exists every launch goes to Welcome;
/// later the gate applies the redirect rules of design system 10.2.
@TypedGoRoute<SplashRoute>(name: 'splash', path: '/')
class SplashRoute extends GoRouteData with $SplashRoute {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => SplashPage(
    onReady: () => const WelcomeRoute().go(context),
  );
}

/// S02 onboarding pager for signed-out users.
@TypedGoRoute<WelcomeRoute>(name: 'welcome', path: '/welcome')
class WelcomeRoute extends GoRouteData with $WelcomeRoute {
  const WelcomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => WelcomePage(
    onSignIn: () => const SignInRoute().push<void>(context),
  );
}

@TypedGoRoute<SignInRoute>(name: 'signIn', path: '/sign-in')
class SignInRoute extends GoRouteData with $SignInRoute {
  const SignInRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SignInPage();
}

/// Debug-only component gallery; release builds land on Home instead.
@TypedGoRoute<GalleryRoute>(name: 'gallery', path: '/gallery')
class GalleryRoute extends GoRouteData with $GalleryRoute {
  const GalleryRoute();

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      kDebugMode ? null : const HomeRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ComponentGalleryPage();
}
