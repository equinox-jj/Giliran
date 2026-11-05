import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/payment_method.dart';
import '../../../../../core/utils/enums/payment_status.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/period.dart';
import '../../../domain/usecases/sort_payment_board_usecase.dart';
import '../controllers/payments_tab_controller.dart';

/// What a row on the Pembayaran tab can open, wired by the group detail
/// page.
typedef PaymentsTabActions = ({
  ValueChanged<Payment> onUpload,
  ValueChanged<Payment> onReview,
  ValueChanged<Payment> onViewProof,
  ValueChanged<Payment> onMarkPaid,
  ValueChanged<Payment> onRemind,
});

/// The Pembayaran tab as slivers inside the group detail scroll
/// view: banners (my proof rejected, draw tomorrow, everyone paid), the
/// summary line, the organizer filter chips and one Payment Row per slot,
/// mine pinned first. An upcoming period shows the `empty_payments` state.
class const PaymentsTab({
  super.key,
  required final GroupDetail group,
  required final Period? period,
  required final PaymentsTabActions actions,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = period;
    final groupId = group.id ?? '';
    if (p == null || p.id == null || p.isUpcoming) {
      return SliverToBoxAdapter(
        child: EmptyState(
          compact: true,
          illustration: const Doodle(AppDoodles.kalender, size: 120),
          title: l10n.paymentsEmptyTitle,
          message: l10n.paymentsEmptyMessage,
        ),
      );
    }
    final provider = paymentsTabControllerProvider(groupId, p.id!);
    final state = ref.watch(provider).value ?? const PaymentsTabState();
    final manager = group.isManager;
    final now = ref.watch(clockProvider)();
    final today = AppDate.jakartaToday(now);

    if (state.all.isEmpty) {
      if (!state.loaded) return const SliverToBoxAdapter(child: _BoardSkeleton());
      return SliverToBoxAdapter(
        child: EmptyState(
          compact: true,
          title: state.failed ? l10n.paymentsLoadFailed : l10n.paymentFilterEmpty,
          primaryLabel: state.failed ? l10n.commonRetry : null,
          onPrimary: state.failed ? () => ref.read(provider.notifier).refresh() : null,
        ),
      );
    }

    final summary = PaymentSummary.fromPayments(state.all);
    final mine = state.all.where((x) => x.mine).firstOrNull;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _BoardHeader(
            summary: summary,
            mine: mine,
            period: p,
            today: today,
            manager: manager,
            filter: state.filter,
            onFilter: ref.watch(provider.notifier).setFilter,
            onUpload: actions.onUpload,
          ),
        ),
        if (state.rows.isEmpty)
          SliverToBoxAdapter(child: EmptyState(compact: true, title: l10n.paymentFilterEmpty))
        else
          SliverList.separated(
            itemCount: state.rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
            itemBuilder: (context, i) => _BoardRow(
              payment: state.rows[i],
              overdue: p.isPastDue(today),
              dueDate: p.dueDate,
              now: now,
              manager: manager,
              actions: actions,
            ),
          ),
      ],
    );
  }
}

class const _BoardHeader({
  required final PaymentSummary summary,
  required final Payment? mine,
  required final Period period,
  required final DateTime today,
  required final bool manager,
  required final PaymentBoardFilter filter,
  required final ValueChanged<PaymentBoardFilter> onFilter,
  required final ValueChanged<Payment> onUpload,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final my = mine;
    final draw = period.drawDate;
    final drawTomorrow = draw != null && draw.difference(today).inDays == 1 && summary.outstandingCount > 0;
    final banners = <Widget>[
      if (my != null && my.status == PaymentStatus.rejected)
        AppBanner(
          variant: AppBannerVariant.error,
          message: l10n.paymentsMyRejected(my.rejectReason ?? ''),
          actionLabel: l10n.heroUploadProof,
          onAction: () => onUpload(my),
        ),
      if (manager && drawTomorrow)
        AppBanner(variant: AppBannerVariant.warning, message: l10n.paymentsDrawTomorrow(summary.outstandingCount)),
      if (summary.allPaid) AppBanner(variant: AppBannerVariant.success, message: l10n.paymentsAllPaid),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in banners)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s3),
              child: b,
            ),
          Text(
            l10n.paymentSummaryLine(
              summary.paidCount ?? 0,
              summary.pendingReviewCount ?? 0,
              summary.outstandingCount,
            ),
            style: t.body.copyWith(color: c.textSecondary),
          ),
          if (manager) ...[
            const SizedBox(height: AppSpace.s3),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [
                for (final f in PaymentBoardFilter.values)
                  AppChip(
                    label: switch (f) {
                      PaymentBoardFilter.all => l10n.paymentFilterAll,
                      PaymentBoardFilter.unpaid => l10n.paymentFilterUnpaid,
                      PaymentBoardFilter.pendingReview => l10n.paymentFilterPending,
                    },
                    count: switch (f) {
                      PaymentBoardFilter.all => null,
                      PaymentBoardFilter.unpaid => summary.outstandingCount,
                      PaymentBoardFilter.pendingReview => summary.pendingReviewCount,
                    },
                    selected: f == filter,
                    onSelected: () => onFilter(f),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class const _BoardRow({
  required final Payment payment,
  required final bool overdue,
  required final DateTime? dueDate,
  required final DateTime now,
  required final bool manager,
  required final PaymentsTabActions actions,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = payment;
    final status = p.status ?? PaymentStatus.unpaid;
    final isOverdue = overdue && p.isOutstanding;
    final mine = p.mine;
    final hasProof = p.currentProof != null;
    final onUpload = mine && p.isOutstanding ? () => actions.onUpload(p) : null;
    final onReview = manager && status == PaymentStatus.pendingReview ? () => actions.onReview(p) : null;
    final menu = manager && p.isOutstanding && onUpload == null
        ? [
            OverflowMenuItem(
              label: l10n.paymentMarkPaidAction,
              icon: AppIcons.handCoins,
              onSelected: () => actions.onMarkPaid(p),
            ),
            OverflowMenuItem(
              label: l10n.memberRemindWhatsApp,
              icon: AppIcons.whatsappLogo,
              onSelected: () => actions.onRemind(p),
            ),
          ]
        : const <OverflowMenuItem>[];
    final VoidCallback? onTap = switch (status) {
      _ when onReview != null => onReview,
      _ when onUpload != null => onUpload,
      PaymentStatus.pendingReview ||
      PaymentStatus.paid when (mine || manager) && hasProof => () => actions.onViewProof(p),
      _ when manager && p.isOutstanding => () => actions.onMarkPaid(p),
      _ => null,
    };
    return PaymentRow(
      slotNo: p.member?.slotNo ?? 0,
      name: p.member?.displayName ?? '',
      status: ChipStatus.fromPayment(status, overdue: isOverdue),
      subtitle: _subtitle(l10n, p, status),
      subtitleAlert: isOverdue,
      guest: p.member?.isGuest ?? false,
      mine: mine,
      pendingSync: p.isPendingSync,
      onTap: onTap,
      onReview: onReview,
      onUpload: onUpload,
      menuItems: menu,
    );
  }

  String _subtitle(AppLocalizations l10n, Payment p, PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        final paid = p.paidAt == null ? '' : l10n.paymentPaidOn(AppDate.smart(p.paidAt!, now: now));
        return p.method == PaymentMethod.cash ? '$paid · ${l10n.paymentMethodCash}' : paid;
      case PaymentStatus.pendingReview:
        final at = p.uploadedAt;
        return at == null ? '' : l10n.paymentUploadedOn(AppDate.smart(at, now: now));
      case PaymentStatus.rejected:
        return p.rejectReason ?? '';
      case PaymentStatus.unpaid:
        final due = dueDate;
        return due == null ? '' : l10n.paymentDueOn(AppDate.short(due, now: AppDate.jakarta(now)));
    }
  }
}

class const _BoardSkeleton() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Skeleton.line(width: 220),
        SizedBox(height: AppSpace.s4),
        Skeleton(height: AppSizes.paymentRowH, radius: AppRadius.lg),
        SizedBox(height: AppSpace.s2),
        Skeleton(height: AppSizes.paymentRowH, radius: AppRadius.lg),
        SizedBox(height: AppSpace.s2),
        Skeleton(height: AppSizes.paymentRowH, radius: AppRadius.lg),
      ],
    );
  }
}
