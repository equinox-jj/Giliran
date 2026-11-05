import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/error/failure.dart';
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
import '../features/history/presentation/group_summary/page/group_summary_page.dart';
import '../features/history/presentation/notifications/page/notifications_page.dart';
import '../features/home/presentation/home/page/home_page.dart';
import '../features/member/presentation/claim/page/claim_page.dart';
import '../features/member/presentation/fixed_order/page/fixed_order_page.dart';
import '../features/member/presentation/invite/page/invite_page.dart';
import '../features/member/presentation/join/page/join_page.dart';
import '../features/member/presentation/leave_requests/page/leave_requests_page.dart';
import '../features/member/presentation/member_detail/page/member_detail_page.dart';
import '../features/member/presentation/shared/widgets/join_link_sheet.dart';
import '../features/member/presentation/start_group/page/start_group_page.dart';
import '../features/member/presentation/transfer_offer/page/transfer_offer_page.dart';
import '../features/member/presentation/transfer_respond/page/transfer_respond_page.dart';
import '../features/draw/presentation/draw_result/page/draw_result_page.dart';
import '../features/draw/presentation/draw_stage/page/draw_stage_page.dart';
import '../features/payment/presentation/payout/page/payout_page.dart';
import '../features/payment/presentation/proof_review/page/proof_review_page.dart';
import '../features/reminder/presentation/reminders/page/reminders_page.dart';
import '../features/payment/presentation/shared/widgets/payment_sync_listener.dart';
import '../features/profile/presentation/delete_account/page/delete_account_page.dart';
import '../features/profile/presentation/edit_profile/page/edit_profile_page.dart';
import '../features/profile/presentation/profile/page/profile_page.dart';
import '../features/profile/presentation/security/page/security_page.dart';
import '../features/settings/presentation/settings/page/settings_page.dart';
import '../shared/widgets/widgets.dart';
import 'component_gallery_page.dart';
import 'deep_link_controller.dart';
import 'push_controller.dart';

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
                TypedGoRoute<GroupSummaryRoute>(
                  name: 'groupSummary',
                  path: 'summary',
                ),
                TypedGoRoute<PaymentInfoRoute>(
                  name: 'paymentInfo',
                  path: 'payment-info',
                ),
                TypedGoRoute<InviteRoute>(
                  name: 'invite',
                  path: 'invite',
                ),
                TypedGoRoute<MemberDetailRoute>(
                  name: 'memberDetail',
                  path: 'members/:mid',
                ),
                TypedGoRoute<FixedOrderRoute>(
                  name: 'fixedOrder',
                  path: 'fixed-order',
                ),
                TypedGoRoute<StartGroupRoute>(
                  name: 'startGroup',
                  path: 'start',
                ),
                TypedGoRoute<LeaveRequestsRoute>(
                  name: 'leaveRequests',
                  path: 'leave-requests',
                ),
                TypedGoRoute<TransferOfferRoute>(
                  name: 'transferOffer',
                  path: 'transfer',
                ),
                TypedGoRoute<TransferRespondRoute>(
                  name: 'transferRespond',
                  path: 'transfer/:tid',
                ),
                TypedGoRoute<ProofReviewRoute>(
                  name: 'proofReview',
                  path: 'payments/:payId/review',
                ),
                TypedGoRoute<DrawRoute>(
                  name: 'draw',
                  path: 'periods/:pid/draw',
                ),
                TypedGoRoute<DrawResultRoute>(
                  name: 'drawResult',
                  path: 'periods/:pid/draw/result',
                ),
                TypedGoRoute<PayoutRoute>(
                  name: 'payout',
                  path: 'periods/:pid/payout',
                ),
                TypedGoRoute<RemindersRoute>(
                  name: 'reminders',
                  path: 'reminders',
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
    return PaymentSyncListener(
      child: AppNavShell(
        body: navigationShell,
        selectedIndex: navigationShell.currentIndex,
        // Re-tapping the active tab pops it back to its root.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
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
    onJoinByLink: () async {
      final code = await showJoinLinkSheet(context);
      if (code != null && context.mounted) JoinRoute(code: code).push<void>(context);
    },
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
    onInvite: () => InviteRoute(gid: gid).push<void>(context),
    onStart: () => StartGroupRoute(gid: gid).push<void>(context),
    onOpenMember: (mid) => MemberDetailRoute(gid: gid, mid: mid).push<void>(context),
    onLeaveRequests: () => LeaveRequestsRoute(gid: gid).push<void>(context),
    onTransfer: () => TransferOfferRoute(gid: gid).push<void>(context),
    onOpenProof: (payId) => ProofReviewRoute(gid: gid, payId: payId).push<void>(context),
    onDraw: (pid) => DrawRoute(gid: gid, pid: pid).push<void>(context),
    onBuktiKocok: (pid) => DrawResultRoute(gid: gid, pid: pid).push<void>(context),
    onPayout: (pid) => PayoutRoute(gid: gid, pid: pid).push<void>(context),
    onSummary: () => GroupSummaryRoute(gid: gid).push<void>(context),
    onReminders: () => RemindersRoute(gid: gid).push<void>(context),
  );
}

/// Group summary (S24) of a completed or closed group, over the tabs.
class const GroupSummaryRoute({required final String gid}) extends GoRouteData with $GroupSummaryRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => GroupSummaryPage(
    groupId: gid,
    onCreateNew: (prefill) => CreateGroupRoute(
      amount: prefill.amount,
      period: prefill.periodType,
      slots: prefill.totalSlots,
    ).push<void>(context),
    onBuktiKocok: (pid) => DrawResultRoute(gid: gid, pid: pid).push<void>(context),
  );
}

/// Draw stage (S37), over the tabs. A finished draw replaces it with the
/// result (S38), playing the reveal when this device ran the draw.
class const DrawRoute({required final String gid, required final String pid}) extends GoRouteData with $DrawRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => DrawStagePage(
    groupId: gid,
    periodId: pid,
    onDrawn: (reveal) => DrawResultRoute(gid: gid, pid: pid, reveal: reveal).pushReplacement(context),
    onClose: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Draw result with the Bukti Kocok (S38), over the tabs. `reveal` plays the
/// winner reveal once.
class const DrawResultRoute({required final String gid, required final String pid, final bool reveal = false})
    extends GoRouteData
    with $DrawResultRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => DrawResultPage(
    groupId: gid,
    periodId: pid,
    reveal: reveal,
    onPayout: () => PayoutRoute(gid: gid, pid: pid).push<void>(context),
    onClose: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Payout (S40), over the tabs.
class const PayoutRoute({required final String gid, required final String pid}) extends GoRouteData with $PayoutRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => PayoutPage(
    groupId: gid,
    periodId: pid,
    onClose: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Reminders and recap (S41) for managers, over the tabs.
class const RemindersRoute({required final String gid}) extends GoRouteData with $RemindersRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => RemindersPage(
    groupId: gid,
    onClose: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Proof review (S35) for managers, or the payer's own proof, over the
/// tabs.
class const ProofReviewRoute({required final String gid, required final String payId})
    extends GoRouteData
    with $ProofReviewRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => ProofReviewPage(
    groupId: gid,
    paymentId: payId,
    onClose: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Edit group (S19), over the tabs.
class const EditGroupRoute({required final String gid}) extends GoRouteData with $EditGroupRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => EditGroupPage(
    groupId: gid,
    onPaymentInfo: () => PaymentInfoRoute(gid: gid).push<void>(context),
    onFixedOrder: () => FixedOrderRoute(gid: gid).push<void>(context),
    onLeaveRequests: () => LeaveRequestsRoute(gid: gid).push<void>(context),
    onTransfer: () => TransferOfferRoute(gid: gid).push<void>(context),
    onReminders: () => RemindersRoute(gid: gid).push<void>(context),
    // Closing ends the group (S19 → S24): the summary replaces Edit group.
    onClosed: () => GroupSummaryRoute(gid: gid).pushReplacement(context),
  );
}

/// Payment info (S15), over the tabs.
class const PaymentInfoRoute({required final String gid}) extends GoRouteData with $PaymentInfoRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => PaymentInfoPage(groupId: gid);
}

/// Invite (S16), over the tabs.
class const InviteRoute({required final String gid}) extends GoRouteData with $InviteRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => InvitePage(groupId: gid);
}

/// Member detail (S26), over the tabs.
class const MemberDetailRoute({required final String gid, required final String mid})
    extends GoRouteData
    with $MemberDetailRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => MemberDetailPage(
    groupId: gid,
    memberId: mid,
    onRemoved: () => _popOr(context, GroupDetailRoute(gid: gid, tab: DetailTab.members.query).location),
  );
}

/// Fixed order (S17), over the tabs.
class const FixedOrderRoute({required final String gid}) extends GoRouteData with $FixedOrderRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => FixedOrderPage(
    groupId: gid,
    onDone: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Start group (S18), over the tabs.
class const StartGroupRoute({required final String gid}) extends GoRouteData with $StartGroupRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => StartGroupPage(
    groupId: gid,
    onInvite: () => InviteRoute(gid: gid).push<void>(context),
    onPaymentInfo: () => PaymentInfoRoute(gid: gid).push<void>(context),
    onFixedOrder: () => FixedOrderRoute(gid: gid).push<void>(context),
    onStarted: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

/// Leave requests review (S31), over the tabs.
class const LeaveRequestsRoute({required final String gid}) extends GoRouteData with $LeaveRequestsRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => LeaveRequestsPage(groupId: gid);
}

/// Transfer ownership offer (S32), over the tabs.
class const TransferOfferRoute({required final String gid}) extends GoRouteData with $TransferOfferRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => TransferOfferPage(groupId: gid);
}

/// Transfer ownership respond (S33), over the tabs. Accepting opens Payment
/// info (S15) in its place.
class const TransferRespondRoute({required final String gid, required final String tid})
    extends GoRouteData
    with $TransferRespondRoute {
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => TransferRespondPage(
    groupId: gid,
    transferId: tid,
    onAccepted: () => PaymentInfoRoute(gid: gid).pushReplacement(context),
    onDone: () => _popOr(context, GroupDetailRoute(gid: gid).location),
  );
}

class const ActivityRoute() extends GoRouteData with $ActivityRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      NotificationsPage(onOpen: (target) => context.go(notificationLocation(target)));
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

/// Join preview (S25), from an invite link `/j/:code`.
@TypedGoRoute<JoinRoute>(
  name: 'join',
  path: '/j/:code',
)
class const JoinRoute({required final String code}) extends GoRouteData with $JoinRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => JoinPage(
    code: code,
    onOpenGroup: (id) => GroupDetailRoute(gid: id).go(context),
    onLater: () => _popOr(context, const HomeRoute().location),
  );
}

/// Claim guest slot (S29), from a claim link `/c/:token`.
@TypedGoRoute<ClaimRoute>(
  name: 'claim',
  path: '/c/:token',
)
class const ClaimRoute({required final String token}) extends GoRouteData with $ClaimRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) => ClaimPage(
    token: token,
    onClaimed: (id) => id == null ? const GroupsRoute().go(context) : GroupDetailRoute(gid: id).go(context),
    onClose: () => _popOr(context, const HomeRoute().location),
  );
}

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
/// Welcome (S02). [invited] is set when the guard turns away an invite
/// link; a link stored by an earlier run shows the banner too.
class const WelcomeRoute({final bool invited = false}) extends GoRouteData with $WelcomeRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) {
    final pending = ProviderScope.containerOf(context, listen: false).read(deepLinkControllerProvider).pending;
    return WelcomePage(
      invited: invited || (pending?.startsWith('/j/') ?? false),
      onSignIn: () => const SignInRoute().push<void>(context),
    );
  }
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
