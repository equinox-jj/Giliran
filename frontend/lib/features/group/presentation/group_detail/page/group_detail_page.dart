import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/services/share_service.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../core/utils/enums/payment_status.dart';
import '../../../../../core/utils/enums/period_status.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../history/presentation/activity_tab/controllers/activity_tab_controller.dart';
import '../../../../history/presentation/activity_tab/widgets/activity_tab.dart';
import '../../../../history/presentation/schedule_tab/widgets/schedule_tab.dart';
import '../../../../member/presentation/members_tab/controllers/members_tab_controller.dart';
import '../../../../member/presentation/members_tab/widgets/members_tab.dart';
import '../../../../member/presentation/shared/controllers/members_controller.dart';
import '../../../../member/presentation/shared/widgets/leave_request_sheet.dart';
import '../../../../payment/domain/entities/payment.dart';
import '../../../../payment/domain/entities/period.dart';
import '../../../../payment/presentation/payments_tab/controllers/payments_tab_controller.dart';
import '../../../../payment/presentation/payments_tab/widgets/payments_tab.dart';
import '../../../../payment/presentation/shared/widgets/mark_paid_sheet.dart';
import '../../../../payment/presentation/shared/widgets/upload_proof_sheet.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/usecases/group_menu_actions_usecase.dart';
import '../../../domain/usecases/pick_hero_action_usecase.dart';
import '../controllers/group_detail_controller.dart';
import '../widgets/detail_tabs.dart';
import '../widgets/group_headline.dart';
import '../widgets/group_menu.dart';

/// The group detail frame (S20–S23): headline, Period Strip, Current Period
/// Hero and the four tabs. [created] shows the "invite now?" prompt once,
/// right after Create group.
class const GroupDetailPage({
  super.key,
  required final String groupId,
  final DetailTab initialTab = DetailTab.payments,
  final bool created = false,
  required final VoidCallback onEdit,
  required final VoidCallback onPaymentInfo,
  required final VoidCallback onInvite,
  required final VoidCallback onStart,
  required final ValueChanged<String> onOpenMember,
  required final VoidCallback onLeaveRequests,
  required final VoidCallback onTransfer,

  /// Opens Proof review (S35) or my own proof for a payment id.
  required final ValueChanged<String> onOpenProof,

  /// Opens the draw stage (S37) for a period id.
  required final ValueChanged<String> onDraw,

  /// Opens the draw result and Bukti Kocok (S38) for a period id.
  required final ValueChanged<String> onBuktiKocok,

  /// Opens the payout (S40) for a period id.
  required final ValueChanged<String> onPayout,

  /// Opens the group summary (S24) of a completed or closed group.
  required final VoidCallback onSummary,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState() extends ConsumerState<GroupDetailPage> {
  late DetailTab _tab = widget.initialTab;

  /// The period the strip and the Pembayaran tab show; null follows the
  /// current period.
  String? _periodId;

  @override
  void initState() {
    super.initState();
    if (widget.created) WidgetsBinding.instance.addPostFrameCallback((_) => _promptInvite());
  }

  Future<void> _promptInvite() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final invite = await showConfirmationSheet(
      context,
      icon: AppIcons.userPlus,
      title: l10n.groupCreatedPrompt,
      confirmLabel: l10n.inviteNowButton,
      cancelLabel: l10n.laterButton,
    );
    if (invite && mounted) widget.onInvite();
  }

  void _comingSoon() => showAppToast(context, context.l10n.comingSoon);

  GroupDetailState? get _detail => ref.read(groupDetailControllerProvider(widget.groupId)).value;

  /// "Lanjutkan persiapan" opens Start group (S18); upload, my proof and
  /// review open the payment screens; draw, payout and Bukti Kocok open
  /// S37, S40 and S38 for the current period.
  void _onHeroAction() {
    final detail = _detail;
    final my = detail?.myPayment;
    final periodId = detail?.currentPeriod?.id;
    switch (detail?.heroAction) {
      case HeroAction.drawNow when periodId != null:
        widget.onDraw(periodId);
      case HeroAction.recordPayout when periodId != null:
        widget.onPayout(periodId);
      case HeroAction.viewBuktiKocok when periodId != null:
        widget.onBuktiKocok(periodId);
      case HeroAction.continueSetup:
        widget.onStart();
      case HeroAction.viewSummary:
        widget.onSummary();
      case HeroAction.uploadProof when my != null:
        _upload(my);
      case HeroAction.viewMyProof when my?.id != null:
        widget.onOpenProof(my!.id!);
      case HeroAction.reviewProofs:
        _reviewFirstPending();
      default:
        _comingSoon();
    }
  }

  /// Opens the first pending proof on the current board, or the Pembayaran
  /// tab when the board isn't cached yet.
  void _reviewFirstPending() {
    final periodId = _detail?.currentPeriod?.id;
    final board = periodId == null
        ? null
        : ref.read(paymentsTabControllerProvider(widget.groupId, periodId)).value?.rows;
    final pending = board?.where((p) => p.status == PaymentStatus.pendingReview).firstOrNull;
    if (pending?.id != null) {
      widget.onOpenProof(pending!.id!);
    } else {
      setState(() => _tab = DetailTab.payments);
    }
  }

  int _periodNoOf(Payment payment) =>
      _detail?.periods.where((p) => p.id == payment.periodId).firstOrNull?.periodNo ??
      _detail?.group?.currentPeriodNo ??
      1;

  Future<void> _upload(Payment payment) async {
    final group = _detail?.group;
    if (group == null) return;
    final sent = await showUploadProofSheet(context, group: group, payment: payment, periodNo: _periodNoOf(payment));
    if (sent && mounted) showAppToast(context, context.l10n.uploadProofSent);
  }

  Future<void> _markPaid(Payment payment) async {
    final saved = await showMarkPaidSheet(context, groupId: widget.groupId, payment: payment);
    if (saved == null || !mounted) return;
    final l10n = context.l10n;
    showAppToast(
      context,
      saved.isPendingSync ? l10n.markPaidQueued : l10n.markPaidDone(payment.member?.displayName ?? ''),
    );
  }

  Future<void> _remind(Payment payment) async {
    final members = ref.read(membersControllerProvider(widget.groupId)).value ?? const [];
    final phone = members.where((m) => m.id == payment.member?.id).firstOrNull?.guestPhone;
    await ref
        .read(shareServiceProvider)
        .openWhatsApp(
          phone: phone,
          text: context.l10n.memberRemindMessage(payment.member?.displayName ?? '', _detail?.group?.name ?? ''),
        );
  }

  /// Opens the leave sheet (S30) with the caller's own obligation when the
  /// Anggota tab has loaded it.
  Future<void> _leave() async {
    final group = ref.read(groupDetailControllerProvider(widget.groupId)).value?.group;
    if (group == null) return;
    final obligations = ref.read(membersTabControllerProvider(widget.groupId)).value?.obligations ?? const [];
    await showLeaveRequestSheet(
      context,
      group: group,
      obligation: obligations.where((o) => o.memberId == group.myMemberId).firstOrNull,
      onTransfer: widget.onTransfer,
    );
  }

  /// Only managers receive the invite link; sharing for members comes with
  /// the group summary (S24).
  void _share() {
    final manager = ref.read(groupDetailControllerProvider(widget.groupId)).value?.group?.isManager ?? false;
    manager ? widget.onInvite() : _comingSoon();
  }

  Future<void> _onMenu(GroupMenuAction action) async {
    switch (action) {
      case GroupMenuAction.edit:
        widget.onEdit();
      case GroupMenuAction.paymentInfo:
        widget.onPaymentInfo();
      case GroupMenuAction.close:
        await _close();
      case GroupMenuAction.invite:
        widget.onInvite();
      case GroupMenuAction.share:
        _share();
      case GroupMenuAction.leave:
        await _leave();
      case GroupMenuAction.reminders:
        _comingSoon();
    }
  }

  Future<void> _close() async {
    final l10n = context.l10n;
    final provider = groupDetailControllerProvider(widget.groupId);
    final name = ref.read(provider).value?.group?.name ?? '';
    final confirmed = await showAppDialog(
      context,
      title: l10n.closeGroupTitle(name),
      message: l10n.closeGroupMessage,
      confirmLabel: l10n.menuClose,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(provider.notifier).close();
    if (!mounted) return;
    showAppToast(context, failure?.displayMessage ?? l10n.groupClosedToast);
    // A closed group is an archive: show its summary (S24).
    if (failure == null) widget.onSummary();
  }

  @override
  Widget build(BuildContext context) {
    final provider = groupDetailControllerProvider(widget.groupId);
    return Scaffold(
      appBar: _DetailTopBar(provider: provider, onShare: _share, onMenu: _onMenu),
      body: _DetailBody(
        provider: provider,
        tab: _tab,
        periodId: _periodId,
        onTab: (t) => setState(() => _tab = t),
        onPeriod: (id) => setState(() {
          _periodId = id;
          _tab = DetailTab.payments;
        }),
        onHeroAction: _onHeroAction,
        tabActions: (
          onInvite: widget.onInvite,
          onOpenMember: widget.onOpenMember,
          onLeaveRequests: widget.onLeaveRequests,
          onLeave: _leave,
          onBuktiKocok: widget.onBuktiKocok,
          payments: (
            onUpload: _upload,
            onReview: (p) => widget.onOpenProof(p.id ?? ''),
            onViewProof: (p) => widget.onOpenProof(p.id ?? ''),
            onMarkPaid: _markPaid,
            onRemind: _remind,
          ),
        ),
      ),
    );
  }
}

class const _DetailTopBar({
  required final GroupDetailControllerProvider provider,
  required final VoidCallback onShare,
  required final ValueChanged<GroupMenuAction> onMenu,
}) extends ConsumerWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.topBarH);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(provider.select((s) => s.value?.group?.name));
    final menu = ref.watch(provider.select((s) => s.value?.menu ?? const <GroupMenuAction>[]));
    final status = ref.watch(provider.select((s) => s.value?.group?.status));
    return AppTopBar(
      title: name,
      collapseTitle: true,
      actions: [
        if (status != GroupStatus.closed)
          CircleIconButton(
            icon: AppIcons.linkSimple,
            semanticLabel: context.l10n.inviteMembersSemantics,
            onPressed: onShare,
          ),
        if (menu.isNotEmpty) GroupMenu(actions: menu, onSelected: onMenu),
      ],
    );
  }
}

enum _Phase() {
  loading,
  notFound,
  content,
}

/// Navigation the tab bodies need from the page.
typedef _TabActions = ({
  VoidCallback onInvite,
  ValueChanged<String> onOpenMember,
  VoidCallback onLeaveRequests,
  VoidCallback onLeave,
  ValueChanged<String> onBuktiKocok,
  PaymentsTabActions payments,
});

class const _DetailBody({
  required final GroupDetailControllerProvider provider,
  required final DetailTab tab,
  required final String? periodId,
  required final ValueChanged<DetailTab> onTab,
  required final ValueChanged<String> onPeriod,
  required final VoidCallback onHeroAction,
  required final _TabActions tabActions,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      provider.select((s) {
        final state = s.value;
        if (state?.group != null) return _Phase.content;
        if (state?.notFound ?? false) return _Phase.notFound;
        return _Phase.loading;
      }),
    );
    final margin = context.screenMargin;
    final bottom = context.isCompact ? AppBottomNavBar.contentInset(context) : AppSpace.s8;

    Future<void> refresh() async {
      final groupId = provider.argument! as String;
      final shownPeriod = periodId ?? ref.read(provider).value?.currentPeriod?.id;
      final results = await Future.wait([
        ref.read(provider.notifier).refresh(),
        if (tab == DetailTab.payments &&
            shownPeriod != null &&
            shownPeriod != ref.read(provider).value?.currentPeriod?.id)
          ref.read(paymentsTabControllerProvider(groupId, shownPeriod).notifier).refresh(),
        if (tab == DetailTab.activity) ref.read(activityTabControllerProvider(groupId).notifier).refresh(),
        if (tab == DetailTab.members) ...[
          ref.read(membersControllerProvider(groupId).notifier).refresh(),
          ref.read(membersTabControllerProvider(groupId).notifier).refresh().then((_) => null),
        ],
      ]);
      final failure = results.nonNulls.firstOrNull;
      if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
    }

    if (phase == _Phase.notFound) {
      final l10n = context.l10n;
      return EmptyState(
        illustration: const Doodle(AppDoodles.rantang, size: 160),
        title: l10n.groupNotFoundTitle,
        message: l10n.groupNotFoundMessage,
      );
    }
    if (phase == _Phase.loading) return _DetailSkeleton(margin: margin);

    final top = _TopSection(provider: provider, periodId: periodId, onPeriod: onPeriod, onHeroAction: onHeroAction);
    final tabs = _TabsSection(provider: provider, tab: tab, onTab: onTab);
    final body = _TabBody(provider: provider, tab: tab, periodId: periodId, actions: tabActions);

    if (context.sizeClass == SizeClass.expanded) {
      // Expanded: the shared top section on the left (5 of 12 columns), the
      // tabs on the right (7 of 12).
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(margin, 0, context.gutter / 2, bottom),
                children: [top],
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(context.gutter / 2, AppSpace.s4, margin, 0),
                  sliver: SliverToBoxAdapter(child: tabs),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(context.gutter / 2, AppSpace.s4, margin, bottom),
                  sliver: body,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            sliver: SliverList.list(
              children: [
                top,
                const SizedBox(height: AppSpace.s6),
                tabs,
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s4, margin, bottom),
            sliver: body,
          ),
        ],
      ),
    );
  }
}

/// The selected tab's body, as a sliver.
class const _TabBody({
  required final GroupDetailControllerProvider provider,
  required final DetailTab tab,
  required final String? periodId,
  required final _TabActions actions,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(provider.select((s) => s.value?.group));
    if (group == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return switch (tab) {
      DetailTab.payments => _PaymentsTabBody(
        provider: provider,
        group: group,
        periodId: periodId,
        actions: actions.payments,
      ),
      DetailTab.members => MembersTab(
        group: group,
        onInvite: actions.onInvite,
        onOpenMember: actions.onOpenMember,
        onLeaveRequests: actions.onLeaveRequests,
        onLeave: actions.onLeave,
      ),
      DetailTab.schedule => _ScheduleTabBody(provider: provider, group: group, onBuktiKocok: actions.onBuktiKocok),
      DetailTab.activity => ActivityTab(groupId: group.id ?? ''),
    };
  }
}

/// The Jadwal tab over the cached periods.
class const _ScheduleTabBody({
  required final GroupDetailControllerProvider provider,
  required final GroupDetail group,
  required final ValueChanged<String> onBuktiKocok,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(provider.select((s) => s.value?.periods ?? const <Period>[]));
    return ScheduleTab(group: group, periods: periods, onBuktiKocok: onBuktiKocok);
  }
}

/// The Pembayaran tab for the selected period (the current one by default).
class const _PaymentsTabBody({
  required final GroupDetailControllerProvider provider,
  required final GroupDetail group,
  required final String? periodId,
  required final PaymentsTabActions actions,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(
      provider.select((s) {
        final state = s.value;
        if (periodId == null) return state?.currentPeriod;
        return state?.periods.where((p) => p.id == periodId).firstOrNull;
      }),
    );
    return PaymentsTab(group: group, period: period, actions: actions);
  }
}

/// Headline, Period Strip and hero.
class const _TopSection({
  required final GroupDetailControllerProvider provider,
  required final String? periodId,
  required final ValueChanged<String> onPeriod,
  required final VoidCallback onHeroAction,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(provider.select((s) => s.value?.group));
    final periods = ref.watch(provider.select((s) => s.value?.periods ?? const <Period>[]));
    final current = ref.watch(provider.select((s) => s.value?.currentPeriod));
    final action = ref.watch(provider.select((s) => s.value?.heroAction ?? HeroAction.none));
    if (group == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s2),
        GroupHeadline(group: group),
        if (group.status != GroupStatus.draft) ...[
          const SizedBox(height: AppSpace.s4),
          PeriodStrip(
            periods: periods.isEmpty ? _tokensFor(group) : _tokensFrom(periods, group.myMemberId),
            selectedPeriodId: periodId ?? current?.id ?? group.currentPeriodId,
            onSelect: periods.isEmpty ? (_) {} : onPeriod,
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        _Hero(group: group, period: current, action: action, onAction: onHeroAction),
      ],
    );
  }

  static List<PeriodTokenData> _tokensFrom(List<Period> periods, String? myMemberId) => [
    for (final p in periods)
      PeriodTokenData(
        id: p.id ?? 'p${p.periodNo}',
        periodNo: p.periodNo ?? 0,
        state: switch (p.status) {
          PeriodStatus.drawn || PeriodStatus.closed => SlotTokenState.done,
          PeriodStatus.open => SlotTokenState.current,
          PeriodStatus.upcoming || null => SlotTokenState.upcoming,
        },
        winnerName: p.winner?.displayName,
        winnerAvatarUrl: p.winner?.avatarUrl,
        iWon: myMemberId != null && p.winner?.id == myMemberId,
      ),
  ];

  /// Tokens from the group alone until periods are cached: the periods
  /// before the current one are done, the rest upcoming.
  static List<PeriodTokenData> _tokensFor(GroupDetail group) {
    final current = group.status == GroupStatus.active ? (group.currentPeriodNo ?? 1) : (group.totalSlots ?? 0) + 1;
    return [
      for (var n = 1; n <= (group.totalSlots ?? 0); n++)
        PeriodTokenData(
          id: n == current ? (group.currentPeriodId ?? 'p$n') : 'p$n',
          periodNo: n,
          state: n < current
              ? SlotTokenState.done
              : n == current
              ? SlotTokenState.current
              : SlotTokenState.upcoming,
        ),
    ];
  }
}

class const _Hero({
  required final GroupDetail group,
  required final Period? period,
  required final HeroAction action,
  required final VoidCallback onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final tone = c.tones[group.toneIndex % c.tones.length];
    final total = group.totalSlots ?? 0;
    if (group.status == GroupStatus.draft) {
      final filled = group.filledSlots ?? 0;
      return CurrentPeriodHero(
        title: group.name ?? '',
        subtitle: l10n.heroSetupTitle,
        ringValue: filled,
        ringTotal: total,
        ringSemantics: l10n.ringFillSemantics(filled, total),
        tone: tone,
        action: action == HeroAction.continueSetup
            ? CurrentPeriodHeroAction(label: l10n.heroContinueSetup, onPressed: onAction)
            : null,
      );
    }
    final summary = period?.paymentSummary;
    final paid = summary?.paidCount ?? group.paidCount ?? 0;
    final pending = summary?.pendingReviewCount ?? group.pendingReviewCount ?? 0;
    final amount = group.amount ?? 0;
    final due = period?.dueDate ?? group.nextDueDate;
    final draw = period?.drawDate ?? group.nextDrawDate;
    final now = DateTime.now();
    return CurrentPeriodHero(
      title: group.name ?? '',
      subtitle: l10n.periodOf(period?.periodNo ?? group.currentPeriodNo ?? 1, total),
      ringValue: paid,
      ringTotal: total,
      ringPending: pending,
      ringSemantics: pending > 0
          ? l10n.ringPaidPendingSemantics(paid, total, pending)
          : l10n.ringPaidSemantics(paid, total),
      amount: summary?.collectedAmount ?? paid * amount,
      amountCaption: l10n.heroCollectedOf(Rupiah.format(group.potAmount ?? amount * total)),
      infoLine: due == null || draw == null
          ? null
          : l10n.heroInfoLine(AppDate.short(due, now: now), AppDate.short(draw, now: now)),
      tone: tone,
      note: action == HeroAction.waitForDraw ? l10n.heroWaitForDraw : null,
      action: switch (action) {
        HeroAction.uploadProof => CurrentPeriodHeroAction(label: l10n.heroUploadProof, onPressed: onAction),
        HeroAction.viewMyProof => CurrentPeriodHeroAction(
          label: l10n.heroViewMyProof,
          onPressed: onAction,
          secondary: true,
        ),
        HeroAction.reviewProofs => CurrentPeriodHeroAction(
          label: l10n.nextActionReviewButton(pending),
          onPressed: onAction,
        ),
        HeroAction.drawNow => CurrentPeriodHeroAction(label: l10n.nextActionDrawButton, onPressed: onAction),
        HeroAction.recordPayout => CurrentPeriodHeroAction(label: l10n.heroRecordPayout, onPressed: onAction),
        HeroAction.viewBuktiKocok => CurrentPeriodHeroAction(
          label: l10n.heroViewBuktiKocok,
          onPressed: onAction,
          secondary: true,
        ),
        HeroAction.viewSummary => CurrentPeriodHeroAction(label: l10n.heroViewSummary, onPressed: onAction),
        HeroAction.continueSetup || HeroAction.waitForDraw || HeroAction.none => null,
      },
    );
  }
}

class const _TabsSection({
  required final GroupDetailControllerProvider provider,
  required final DetailTab tab,
  required final ValueChanged<DetailTab> onTab,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      provider.select((s) {
        final state = s.value;
        final count = state?.pendingCount ?? 0;
        return (state?.group?.isManager ?? false) && count > 0 ? count : null;
      }),
    );
    return DetailTabs(selected: tab, onChanged: onTab, pendingCount: pending);
  }
}

class const _DetailSkeleton({required final double margin}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: AppSpace.s4),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton.line(width: 260, height: 28),
          SizedBox(height: AppSpace.s4),
          Skeleton(height: 66, radius: AppRadius.full),
          SizedBox(height: AppSpace.s4),
          Skeleton(height: AppSizes.heroMinH, radius: AppRadius.xl),
        ],
      ),
    );
  }
}
