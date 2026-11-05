import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/invite_preview.dart';
import '../controllers/join_controller.dart';

/// Join preview for invite [code]: who invites, the dues, the start
/// date and the slot fill, then "Gabung". An existing member gets "Buka
/// grup"; a full or started group a banner and a disabled button; a bad
/// code the "Link undangan tidak berlaku" empty state.
class const JoinPage({
  super.key,
  required final String code,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onLater,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = joinControllerProvider(code);
    final failure = ref.watch(provider.select((s) => s.hasValue ? null : s.error));
    final loaded = ref.watch(provider.select((s) => s.hasValue));
    return Scaffold(
      appBar: AppTopBar(onBack: onLater),
      body: switch ((loaded, failure)) {
        (true, _) => _JoinContent(code: code, onOpenGroup: onOpenGroup, onLater: onLater),
        (false, final Failure f) when f.apiCode == ApiErrorCode.inviteNotFound || f is NotFoundFailure => EmptyState(
          illustration: const Doodle(AppDoodles.slip, size: 160),
          title: l10n.joinInvalidTitle,
          message: l10n.joinInvalidMessage,
          primaryLabel: l10n.joinLater,
          onPrimary: onLater,
        ),
        (false, final Failure f) => EmptyState(
          title: l10n.joinInvalidTitle,
          message: f.displayMessage(context.l10n),
          primaryLabel: l10n.commonRetry,
          onPrimary: () => ref.invalidate(provider),
        ),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

class const _JoinContent({
  required final String code,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onLater,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = joinControllerProvider(code);
    final preview = ref.watch(provider.select((s) => s.value?.preview)) ?? const InvitePreview();
    final joining = ref.watch(provider.select((s) => s.value?.joining ?? false));
    final already = preview.alreadyMember ?? false;
    final canJoin = preview.canJoin ?? false;
    final blocked = !already && !canJoin;
    final full = (preview.filledSlots ?? 0) >= (preview.totalSlots ?? 0);
    final tone = c.tones[GiliranColors.toneIndexFor(preview.groupId ?? '', count: c.tones.length)];

    Future<void> join() async {
      final outcome = await ref.read(provider.notifier).join();
      if (!context.mounted) return;
      if (outcome.groupId case final id?) {
        showAppToast(context, l10n.joinedToast);
        onOpenGroup(id);
      } else if (outcome.failure case final f?) {
        showAppToast(context, f.displayMessage(context.l10n));
      }
    }

    final unit = preview.periodType == PeriodType.weekly ? l10n.periodUnitWeekly : l10n.periodUnitMonthly;
    final amount = preview.amount ?? 0;
    final total = preview.totalSlots ?? 0;
    final filled = preview.filledSlots ?? 0;
    final start = preview.startDate;
    return MaxWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
        children: [
          const Center(child: Doodle(AppDoodles.hands, size: 112)),
          const SizedBox(height: AppSpace.s4),
          HeadlineText(l10n.joinHeadline(preview.organizer?.name ?? '', preview.groupName ?? '')),
          const SizedBox(height: AppSpace.s6),
          AppCard(
            color: tone.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GiliranRing(
                    value: filled,
                    total: total,
                    size: GiliranRingSize.s64,
                    color: tone.accent,
                    semanticsLabel: l10n.joinSlotsValue(filled, total),
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
                KeyValueList(
                  items: [
                    KeyValueItem(l10n.joinDues, l10n.amountPerPeriod(Rupiah.format(amount), unit)),
                    if (start != null) KeyValueItem(l10n.joinStart, AppDate.full(start)),
                    KeyValueItem(l10n.joinSlots, l10n.joinSlotsValue(filled, total)),
                    KeyValueItem(l10n.joinPot, Rupiah.format(amount * total)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(AppIcons.shieldCheck, size: 20, color: c.textSecondary),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(l10n.joinTrustNote, style: t.body.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          if (blocked) ...[
            const SizedBox(height: AppSpace.s4),
            AppBanner(
              message: full || preview.status == GroupStatus.draft ? l10n.joinFullBanner : l10n.joinStartedBanner,
              variant: AppBannerVariant.warning,
            ),
          ],
          const SizedBox(height: AppSpace.s6),
          if (already)
            AppButton(label: l10n.joinOpenGroup, block: true, onPressed: () => onOpenGroup(preview.groupId ?? ''))
          else
            AppButton(label: l10n.joinButton, block: true, loading: joining, onPressed: blocked ? null : join),
          const SizedBox(height: AppSpace.s2),
          AppButton.ghost(label: l10n.joinLater, block: true, onPressed: onLater),
        ],
      ),
    );
  }
}
