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
class const AppShellRoute() extends StatefulShellRouteData {
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

class const HomeBranch() extends StatefulShellBranchData;

class const GroupsBranch() extends StatefulShellBranchData;

class const ActivityBranch() extends StatefulShellBranchData;

class const ProfileBranch() extends StatefulShellBranchData;

class const HomeRoute() extends GoRouteData with $HomeRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

class const GroupsRoute() extends GoRouteData with $GroupsRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const GroupsPage();
}

class const ActivityRoute() extends GoRouteData with $ActivityRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const ActivityPage();
}

class const ProfileRoute() extends GoRouteData with $ProfileRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const ProfilePage();
}

/// S01 launch gate. Until auth state exists every launch goes to Welcome;
/// later the gate applies the redirect rules of design system 10.2.
@TypedGoRoute<SplashRoute>(name: 'splash', path: '/')
class const SplashRoute() extends GoRouteData with $SplashRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => SplashPage(
    onReady: () => const WelcomeRoute().go(context),
  );
}

/// S02 onboarding pager for signed-out users.
@TypedGoRoute<WelcomeRoute>(name: 'welcome', path: '/welcome')
class const WelcomeRoute() extends GoRouteData with $WelcomeRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => WelcomePage(
    onSignIn: () => const SignInRoute().push<void>(context),
  );
}

@TypedGoRoute<SignInRoute>(name: 'signIn', path: '/sign-in')
class const SignInRoute() extends GoRouteData with $SignInRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const SignInPage();
}

/// Debug-only component gallery; release builds land on Home instead.
@TypedGoRoute<GalleryRoute>(name: 'gallery', path: '/gallery')
class const GalleryRoute() extends GoRouteData with $GalleryRoute {
  @override
  String? redirect(BuildContext context, GoRouterState state) => kDebugMode ? null : const HomeRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) => const ComponentGalleryPage();
}
