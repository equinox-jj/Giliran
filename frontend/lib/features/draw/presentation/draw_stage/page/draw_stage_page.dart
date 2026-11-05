import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/usecases/plan_draw_stage_usecase.dart';
import '../../shared/controllers/draw_controller.dart';
import '../controllers/draw_stage_plan_provider.dart';
import '../widgets/draw_stage_sheets.dart';

/// Draw stage (S37): the kaleng with the eligible slots, the published
/// commitment, and for organizers the Kocok button (from `draw_date`,
/// online). Members watch with "Pengurus akan mengocok…". A finished draw
/// leaves through [onDrawn]: `true` right after this device ran it (play the
/// reveal), `false` when it was already drawn.
class const DrawStagePage({
  super.key,
  required final String groupId,
  required final String periodId,
  required final ValueChanged<bool> onDrawn,
  required final VoidCallback onClose,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<DrawStagePage> createState() => _DrawStagePageState();
}

class _DrawStagePageState() extends ConsumerState<DrawStagePage> {
  DrawControllerProvider get _draw => drawControllerProvider(widget.groupId, widget.periodId);

  final _busy = ValueNotifier(false);
  final _shake = ValueNotifier(0);
  var _left = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(_draw, (_, next) {
      // Opened on a period that is already drawn: go straight to the result.
      if (next.value?.isDrawn == true && !_busy.value) _leave(reveal: false);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _busy.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _leave({required bool reveal}) {
    if (_left) return;
    _left = true;
    widget.onDrawn(reveal);
  }

  Future<void> _run({bool confirmIncomplete = false}) async {
    if (_busy.value) return;
    _busy.value = true;
    final failure = await ref.read(_draw.notifier).run(confirmIncomplete: confirmIncomplete);
    if (!mounted) return;
    if (failure == null) {
      _shake.value++;
      await Future<void>.delayed(DrawStage.shakeDuration);
      if (mounted) _leave(reveal: true);
      return;
    }
    _busy.value = false;
    await _onFailure(failure);
  }

  Future<void> _onFailure(Failure failure) async {
    final l10n = context.l10n;
    switch (failure) {
      case ConflictFailure(code: ApiErrorCode.paymentsIncomplete, :final extensions):
        final paid = (extensions['paid_count'] as num?)?.toInt() ?? 0;
        final total = (extensions['total_count'] as num?)?.toInt() ?? 0;
        final confirmed = await showConfirmationSheet(
          context,
          icon: AppIcons.warningCircle,
          title: l10n.drawIncompleteTitle(paid, total),
          confirmLabel: l10n.drawConfirm,
          cancelLabel: l10n.commonCancel,
          consentLabel: l10n.drawIncompleteConsent,
        );
        if (confirmed && mounted) await _run(confirmIncomplete: true);
      case ConflictFailure(code: ApiErrorCode.drawAlreadyDone):
        _leave(reveal: false);
      default:
        showAppToast(context, failure.displayMessage(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;
    return Scaffold(
      appBar: AppTopBar(onBack: widget.onClose),
      body: MaxWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s8),
          children: [
            _Headline(groupId: widget.groupId, periodId: widget.periodId),
            const SizedBox(height: AppSpace.s5),
            _Stage(
              groupId: widget.groupId,
              periodId: widget.periodId,
              busy: _busy,
              shake: _shake,
              onRun: _run,
            ),
            const SizedBox(height: AppSpace.s4),
            _Caption(groupId: widget.groupId, periodId: widget.periodId),
          ],
        ),
      ),
    );
  }
}

/// "Kocokan **periode 4**".
class const _Headline({required final String groupId, required final String periodId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(
      groupDetailControllerProvider(
        groupId,
      ).select((s) => s.value?.periods.where((p) => p.id == periodId).firstOrNull?.periodNo),
    );
    final drawNo = ref.watch(drawControllerProvider(groupId, periodId).select((s) => s.value?.periodNo));
    return HeadlineText(context.l10n.drawStageTitle(n ?? drawNo ?? 0));
  }
}

class const _Stage({
  required final String groupId,
  required final String periodId,
  required final ValueNotifier<bool> busy,
  required final ValueNotifier<int> shake,
  required final Future<void> Function() onRun,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(drawStagePlanProvider(groupId, periodId));
    final draw = ref.watch(drawControllerProvider(groupId, periodId));
    if (draw case AsyncError(:final error)) {
      return AppBanner(
        message: error is Failure ? error.displayMessage(context.l10n) : l10n.drawLoadFailed,
        variant: AppBannerVariant.error,
        actionLabel: l10n.commonRetry,
        onAction: () => ref.invalidate(drawControllerProvider(groupId, periodId)),
      );
    }
    if (plan == null) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator.adaptive()));
    final hash = plan.fixedOrder ? null : draw.value?.seedHash;
    final next = plan.nextInOrder;
    final people = [
      for (final m in plan.eligible)
        AvatarData(name: m.displayName ?? '', imageUrl: m.avatarUrl, guest: m.isGuest ?? false),
    ];
    return ValueListenableBuilder(
      valueListenable: busy,
      builder: (context, running, _) => ValueListenableBuilder(
        valueListenable: shake,
        builder: (context, token, _) => DrawStage(
          tone: context.colors.toneFor(groupId),
          people: people,
          featured: next == null
              ? null
              : AvatarData(name: next.displayName ?? '', imageUrl: next.avatarUrl, guest: next.isGuest ?? false),
          commitmentHash: hash,
          onCommitmentTap: hash == null ? null : () => showCommitmentSheet(context, hash: hash),
          showDrawButton: plan.manager,
          drawLabel: plan.fixedOrder ? l10n.drawFixedButton : l10n.drawButton,
          onDraw: plan.canRun && !running && draw.hasValue ? onRun : null,
          onPeople: () => showEligibleSheet(context, eligible: plan.eligible),
          onHelp: () => showDrawHelpSheet(context),
          shakeToken: token,
        ),
      ),
    );
  }
}

/// The eligible avatars with their count, and why the viewer can't draw.
class const _Caption({required final String groupId, required final String periodId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final plan = ref.watch(drawStagePlanProvider(groupId, periodId));
    if (plan == null) return const SizedBox.shrink();
    final reason = switch (plan.blocker) {
      DrawBlocker.notManager => l10n.drawMemberCaption,
      DrawBlocker.tooEarly when plan.availableOn != null => l10n.drawAvailableOn(AppDate.short(plan.availableOn!)),
      DrawBlocker.offline => l10n.needsConnection,
      _ => null,
    };
    return Column(
      children: [
        if (!plan.fixedOrder && plan.eligible.isNotEmpty) ...[
          AvatarStack(
            people: [
              for (final m in plan.eligible)
                AvatarData(name: m.displayName ?? '', imageUrl: m.avatarUrl, guest: m.isGuest ?? false),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(l10n.drawEligibleCount(plan.eligible.length), style: t.caption.copyWith(color: c.textSecondary)),
        ],
        if (reason != null) ...[
          const SizedBox(height: AppSpace.s3),
          Semantics(
            liveRegion: true,
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}
