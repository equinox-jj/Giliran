import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/error/failure.dart';
import '../core/l10n/l10n.dart';
import '../features/auth/domain/entities/auth_status.dart';
import '../features/auth/presentation/biometric_opt_in/page/biometric_opt_in_page.dart';
import '../features/auth/presentation/change_email/page/change_email_page.dart';
import '../features/auth/presentation/change_pin/page/change_pin_page.dart';
import '../features/auth/presentation/fill_name/page/fill_name_page.dart';
import '../features/auth/presentation/forgot_pin/page/forgot_pin_page.dart';
import '../features/auth/presentation/pin_lock/page/pin_lock_page.dart';
import '../features/auth/presentation/set_pin/page/set_pin_page.dart';
import '../features/auth/presentation/shared/controllers/auth_session_controller.dart';
import '../features/auth/presentation/sign_in/page/sign_in_page.dart';
import '../features/auth/presentation/splash/page/splash_page.dart';
import '../features/auth/presentation/verify_otp/page/verify_otp_page.dart';
import '../features/auth/presentation/welcome/page/welcome_page.dart';
import '../core/utils/enums/period_type.dart';
import '../features/group/presentation/create_group/page/create_group_page.dart';
import '../features/group/presentation/edit_group/page/edit_group_page.dart';
import '../features/group/presentation/group_detail/page/group_detail_page.dart';
import '../features/group/presentation/group_detail/widgets/detail_tabs.dart';
import '../features/group/presentation/groups/page/groups_page.dart';
import '../features/group/presentation/payment_info/page/payment_info_page.dart';
import '../features/history/presentation/pages/activity_page.dart';
import '../features/home/presentation/home/page/home_page.dart';
import '../features/profile/presentation/delete_account/page/delete_account_page.dart';
import '../features/profile/presentation/edit_profile/page/edit_profile_page.dart';
import '../features/profile/presentation/profile/page/profile_page.dart';
import '../features/profile/presentation/security/page/security_page.dart';
import '../features/settings/presentation/settings/page/settings_page.dart';
import '../shared/widgets/widgets.dart';
import 'component_gallery_page.dart';

part 'routes.g.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
          routes: [
            TypedGoRoute<CreateGroupRoute>(
              name: 'createGroup',
              path: 'new',
            ),
            TypedGoRoute<GroupDetailRoute>(
              name: 'groupDetail',
              path: ':gid',
              routes: [
                TypedGoRoute<EditGroupRoute>(
                  name: 'editGroup',
                  path: 'edit',
                ),
                TypedGoRoute<PaymentInfoRoute>(
                  name: 'paymentInfo',
                  path: 'payment-info',
                ),
              ],
            ),
          ],
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
          routes: [
            TypedGoRoute<EditProfileRoute>(
              name: 'editProfile',
              path: 'edit',
            ),
            TypedGoRoute<SettingsRoute>(
              name: 'settings',
              path: 'settings',
            ),
            TypedGoRoute<DeleteAccountRoute>(
              name: 'deleteAccount',
              path: 'delete',
            ),
            TypedGoRoute<SecurityRoute>(
              name: 'security',
              path: 'security',
              routes: [
                TypedGoRoute<ChangePinRoute>(
                  name: 'changePin',
                  path: 'pin',
                  routes: [
                    TypedGoRoute<SecurityForgotPinRoute>(
                      name: 'securityForgotPin',
                      path: 'forgot',
                    ),
                  ],
                ),
                TypedGoRoute<ChangeEmailRoute>(
                  name: 'changeEmail',
                  path: 'email',
                ),
              ],
            ),
          ],
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
  Widget build(BuildContext context, GoRouterState state) => HomePage(
    onOpenGroup: (id) => GroupDetailRoute(gid: id).go(context),
    onCreateGroup: () => const CreateGroupRoute().push<void>(context),
    // The paste-invite-link sheet comes with Members (Phase 3).
    onJoinByLink: () => showAppToast(context, context.l10n.comingSoon),
    onAvatar: () => const ProfileRoute().go(context),
    onBell: () => const ActivityRoute().go(context),
  );
}

class const GroupsRoute() extends GoRouteData with $GroupsRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => GroupsPage(
    onOpenGroup: (id) => GroupDetailRoute(gid: id).go(context),
    onCreateGroup: () => const CreateGroupRoute().push<void>(context),
  );
}

/// Create group (S13–S14), a full-screen modal over the tabs. The query
/// carries the S24 "Buat arisan baru" prefill.
class const CreateGroupRoute({final int? amount, final PeriodType? period, final int? slots})
    extends GoRouteData
    with $CreateGroupRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => MaterialPage<void>(
    key: state.pageKey,
    fullscreenDialog: true,
    child: CreateGroupPage(
      prefillAmount: amount,
      prefillPeriodType: period,
      prefillTotalSlots: slots,
      onCreated: (id) => GroupDetailRoute(gid: id, created: true).go(context),
    ),
  );
}

/// Group detail (S20–S23). `?tab=pembayaran|jadwal|anggota|aktivitas`
/// picks the tab; `created` shows the invite prompt after Create group.
class const GroupDetailRoute({required final String gid, final String? tab, final bool created = false})
    extends GoRouteData
    with $GroupDetailRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => GroupDetailPage(
    key: ValueKey(gid),
    groupId: gid,
    initialTab: DetailTab.fromQuery(tab),
    created: created,
    onEdit: () => EditGroupRoute(gid: gid).push<void>(context),
    onPaymentInfo: () => PaymentInfoRoute(gid: gid).push<void>(context),
  );
}

/// Edit group (S19), over the tabs.
class const EditGroupRoute({required final String gid}) extends GoRouteData with $EditGroupRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => EditGroupPage(
    groupId: gid,
    onPaymentInfo: () => PaymentInfoRoute(gid: gid).push<void>(context),
    onClosed: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Payment info (S15), over the tabs.
class const PaymentInfoRoute({required final String gid}) extends GoRouteData with $PaymentInfoRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => PaymentInfoPage(groupId: gid);
}

class const ActivityRoute() extends GoRouteData with $ActivityRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const ActivityPage();
}

class const ProfileRoute() extends GoRouteData with $ProfileRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => ProfilePage(
    onEdit: () => const EditProfileRoute().push<void>(context),
    onSecurity: () => const SecurityRoute().push<void>(context),
    onSettings: () => const SettingsRoute().push<void>(context),
  );
}

class const EditProfileRoute() extends GoRouteData with $EditProfileRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => EditProfilePage(
    onChangeEmail: () => const ChangeEmailRoute().push<void>(context),
    onDone: () => _popOr(context, const ProfileRoute().location),
  );
}

class const SettingsRoute() extends GoRouteData with $SettingsRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => SettingsPage(
    onDeleteAccount: () => const DeleteAccountRoute().push<void>(context),
  );
}

class const DeleteAccountRoute() extends GoRouteData with $DeleteAccountRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => DeleteAccountPage(
    onClose: () => _popOr(context, const SettingsRoute().location),
    onForgotPin: () => const SecurityForgotPinRoute().push<void>(context),
  );
}

class const SecurityRoute() extends GoRouteData with $SecurityRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => SecurityPage(
    onChangePin: () => const ChangePinRoute().push<void>(context),
    onChangeEmail: () => const ChangeEmailRoute().push<void>(context),
  );
}

class const ChangePinRoute() extends GoRouteData with $ChangePinRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => ChangePinPage(
    onDone: () => _popOr(context, const ProfileRoute().location),
    onForgotPin: () => const SecurityForgotPinRoute().push<void>(context),
  );
}

class const ChangeEmailRoute() extends GoRouteData with $ChangeEmailRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => ChangeEmailPage(
    onDone: () => _popOr(context, const ProfileRoute().location),
    onForgotPin: () => const SecurityForgotPinRoute().push<void>(context),
  );
}

class const SecurityForgotPinRoute() extends GoRouteData with $SecurityForgotPinRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final status = ProviderScope.containerOf(context).read(authSessionControllerProvider).value;
    return ForgotPinPage(
      email: status is AuthUnlocked ? status.user?.email : null,
      onBack: () => _popOr(context, const ChangePinRoute().location),
      onDone: () => const ProfileRoute().go(context),
    );
  }
}

/// Pops the current route, or goes to [fallback] when it was opened
/// directly (a deep link) and has nothing under it.
void _popOr(BuildContext context, String fallback) => context.canPop() ? context.pop() : context.go(fallback);

@TypedGoRoute<SplashRoute>(
  name: 'splash',
  path: '/',
)
class const SplashRoute() extends GoRouteData with $SplashRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => SplashPage(
    onReady: () => _leave(context),
  );

  Future<void> _leave(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(authSessionControllerProvider.future);
    } on Failure {
      // The guard treats a failed session read as signed out.
    }
    if (context.mounted) const HomeRoute().go(context);
  }
}

@TypedGoRoute<WelcomeRoute>(
  name: 'welcome',
  path: '/welcome',
)
class const WelcomeRoute() extends GoRouteData with $WelcomeRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => WelcomePage(
    onSignIn: () => const SignInRoute().push<void>(context),
  );
}

@TypedGoRoute<SignInRoute>(
  name: 'signIn',
  path: '/auth/email',
)
class const SignInRoute({final String? $extra}) extends GoRouteData with $SignInRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => SignInPage(
    initialEmail: $extra,
    onCodeSent: () => const VerifyOtpRoute().push<void>(context),
  );
}

@TypedGoRoute<VerifyOtpRoute>(
  name: 'verifyOtp',
  path: '/auth/email/code',
)
class const VerifyOtpRoute() extends GoRouteData with $VerifyOtpRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => VerifyOtpPage(
    onChangeEmail: (email) {
      if (context.canPop()) {
        context.pop();
      } else {
        SignInRoute($extra: email).go(context);
      }
    },
    onForgotPin: (email) => ForgotPinRoute($extra: email).push<void>(context),
  );
}

@TypedGoRoute<FillNameRoute>(
  name: 'fillName',
  path: '/auth/name',
)
class const FillNameRoute() extends GoRouteData with $FillNameRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const FillNamePage();
}

@TypedGoRoute<SetPinRoute>(
  name: 'setPin',
  path: '/auth/pin/new',
)
class const SetPinRoute() extends GoRouteData with $SetPinRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => const SetPinPage();
}

@TypedGoRoute<BiometricRoute>(
  name: 'biometric',
  path: '/auth/biometric',
)
class const BiometricRoute() extends GoRouteData with $BiometricRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => BiometricOptInPage(
    onDone: () => const HomeRoute().go(context),
  );
}

@TypedGoRoute<LockRoute>(
  name: 'lock',
  path: '/lock',
)
class const LockRoute({final String? from}) extends GoRouteData with $LockRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => PinLockPage(
    onForgotPin: (email) => ForgotPinRoute($extra: email).push<void>(context),
  );
}

@TypedGoRoute<ForgotPinRoute>(
  name: 'forgotPin',
  path: '/auth/pin/forgot',
)
class const ForgotPinRoute({final String? $extra}) extends GoRouteData with $ForgotPinRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => ForgotPinPage(
    email: $extra,
    // The splash hands over to the guard, which picks the right screen.
    onBack: () => context.canPop() ? context.pop() : const SplashRoute().go(context),
  );
}

/// Debug-only component gallery; release builds land on Home instead.
@TypedGoRoute<GalleryRoute>(
  name: 'gallery',
  path: '/gallery',
)
class const GalleryRoute() extends GoRouteData with $GalleryRoute {
  @override
  String? redirect(BuildContext context, GoRouterState state) => kDebugMode ? null : const HomeRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) => const ComponentGalleryPage();
}
