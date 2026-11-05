import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/services/share_service.dart';
import '../../../../../core/services/widget_image_exporter.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/logger/app_logger.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/recap.dart';
import '../../../domain/usecases/build_whatsapp_reminder_usecase.dart';
import '../controllers/reminders_controller.dart';
import '../widgets/skipped_reminders_sheet.dart';

/// Reminders and recap: the recap image of the current
/// period to share to the group chat, one-tap WhatsApp reminders per
/// unpaid member, and a push reminder to the selected members.
class const RemindersPage({
  super.key,
  required final String groupId,
  required final VoidCallback onClose,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = remindersControllerProvider(groupId);
    final async = ref.watch(provider);
    final hasUnpaid = ref.watch(provider.select((s) => s.value?.recap.unpaid.isNotEmpty ?? false));

    return Scaffold(
      appBar: AppTopBar(title: l10n.editGroupRemindersRecap, onBack: onClose),
      body: switch (async) {
        AsyncData(:final value) => _Content(groupId: groupId, recap: value.recap),
        AsyncError(:final error) => _LoadError(groupId: groupId, error: error),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
      bottomNavigationBar: hasUnpaid ? _SendBar(groupId: groupId) : null,
    );
  }
}

/// Opens WhatsApp with the pre-filled reminder for one member.
Future<void> _openWhatsApp(BuildContext context, WidgetRef ref, Recap recap, String name, String phone) {
  final l10n = context.l10n;
  final text = ref.read(buildWhatsAppReminderUseCaseProvider)((
    memberName: name,
    recap: recap,
    now: ref.read(clockProvider)(),
    copy: (
      body: l10n.remindersWhatsAppBody,
      account: l10n.remindersWhatsAppAccount,
      closing: l10n.remindersWhatsAppClosing,
    ),
  ));

  return ref.read(shareServiceProvider).openWhatsApp(phone: phone, text: text);
}

class const _LoadError({required final String groupId, required final Object error}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final failure = error is Failure ? error as Failure : null;
    if (failure?.apiCode == ApiErrorCode.periodNotOpen) {
      return EmptyState(
        illustration: const Doodle(AppDoodles.kalender, size: 96),
        title: l10n.remindersNoPeriodTitle,
        message: l10n.remindersNoPeriodMessage,
      );
    }

    return EmptyState(
      title: failure?.displayMessage(context.l10n) ?? l10n.commonRetry,
      primaryLabel: l10n.commonRetry,
      onPrimary: () => ref.invalidate(remindersControllerProvider(groupId)),
    );
  }
}

class const _Content({required final String groupId, required final Recap recap}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final margin = context.screenMargin;
    final unpaid = recap.unpaid;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(remindersControllerProvider(groupId).future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, 0),
            sliver: SliverToBoxAdapter(
              child: MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (recap.allPaid)
                      EmptyState(
                        compact: true,
                        illustration: const Doodle(AppDoodles.gelas, size: 72),
                        title: l10n.remindersAllPaidTitle,
                        message: l10n.remindersAllPaidMessage,
                      )
                    else
                      Semantics(
                        header: true,
                        child: HeadlineText(l10n.remindersHeadline(unpaid.length, recap.periodNo ?? 0)),
                      ),
                    const SizedBox(height: AppSpace.s5),
                    _RecapPreview(groupId: groupId, recap: recap),
                    if (unpaid.isNotEmpty) SectionHeader(title: l10n.remindersOneByOne),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, 0, margin, AppSpace.s8),
            sliver: SliverList.builder(
              itemCount: unpaid.length,
              itemBuilder: (context, i) => MaxWidth(
                child: _UnpaidRow(groupId: groupId, recap: recap, unpaid: unpaid[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The recap card scaled to fit, and "Bagikan rekap ke grup WhatsApp",
/// which exports the same frame at 1080 × 1350 and opens the share sheet.
class const _RecapPreview({required final String groupId, required final Recap recap}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final card = _RecapImage(groupId: groupId, recap: recap, now: ref.watch(clockProvider)());

    Future<void> share() async {
      final Uint8List png;
      try {
        png = await ref
            .read(widgetImageExporterProvider)
            .export(
              RecapExportFrame(card: card),
              logicalSize: RecapExportFrame.size,
              pixelRatio: RecapExportFrame.pixelRatio,
              inherit: context,
            );
      } on Exception catch (e, st) {
        AppLogger.w('Recap export failed', tag: 'reminder', error: e, stackTrace: st);
        if (context.mounted) showAppToast(context, l10n.remindersExportFailed);
        return;
      }
      await ref
          .read(shareServiceProvider)
          .shareImage(png, text: l10n.remindersShareText(recap.groupName ?? '', recap.periodNo ?? 0));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AspectRatio(
              aspectRatio: RecapExportFrame.size.aspectRatio,
              child: FittedBox(child: RecapExportFrame(card: card)),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        AppButton(label: l10n.remindersShareRecap, icon: AppIcons.whatsappLogo, onPressed: share),
      ],
    );
  }
}

/// The recap card for [recap], previewed and exported alike.
class const _RecapImage({required final String groupId, required final Recap recap, required final DateTime now})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final info = recap.paymentInfo;
    return RecapCard(
      groupName: recap.groupName ?? '',
      periodNo: recap.periodNo ?? 0,
      totalPeriods: recap.totalPeriods ?? 0,
      paidCount: recap.paidCount ?? 0,
      totalCount: recap.totalCount ?? 0,
      collectedAmount: recap.collectedAmount ?? 0,
      expectedAmount: recap.expectedAmount ?? 0,
      unpaidNames: [for (final u in recap.unpaid) u.member?.displayName ?? ''],
      dueDate: recap.dueDate,
      drawDate: recap.drawDate,
      account: info != null && info.hasBankAccount
          ? context.l10n.recapAccount(info.bankName ?? '', info.accountNumber ?? '', info.accountHolder ?? '')
          : null,
      tone: GiliranColors.exportTones[GiliranColors.toneIndexFor(groupId, count: GiliranColors.exportTones.length)],
      now: now,
    );
  }
}

/// One unpaid member: the push check box (not for guests, who have no app)
/// and a WhatsApp button when their number is known.
class const _UnpaidRow({required final String groupId, required final Recap recap, required final RecapUnpaid unpaid})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final member = unpaid.member;
    final id = member?.id ?? '';
    final name = member?.displayName ?? '';
    final guest = member?.isGuest ?? false;
    final provider = remindersControllerProvider(groupId);
    final selected = ref.watch(provider.select((s) => s.value?.selected.contains(id) ?? false));
    final busy = ref.watch(provider.select((s) => s.value?.busy ?? false));
    final phone = unpaid.whatsappPhone;
    return Row(
      children: [
        Expanded(
          child: CheckRow(
            label: name,
            value: selected,
            subtitle: guest
                ? l10n.remindersGuestCaption
                : l10n.memberSlotCaption(CodeFormatter.slotNo(member?.slotNo ?? 0)),
            onChanged: guest || busy ? null : (v) => ref.read(provider.notifier).toggle(id, v),
          ),
        ),
        if (phone != null) ...[
          const SizedBox(width: AppSpace.s2),
          CircleIconButton(
            icon: AppIcons.whatsappLogo,
            semanticLabel: l10n.remindersWhatsAppSemantics(name),
            onPressed: () => _openWhatsApp(context, ref, recap, name, phone),
          ),
        ],
      ],
    );
  }
}

/// The docked "Kirim notifikasi ke {n} orang", with the countdown after a
/// rate limit.
class const _SendBar({required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final provider = remindersControllerProvider(groupId);
    final count = ref.watch(provider.select((s) => s.value?.selected.length ?? 0));
    final busy = ref.watch(provider.select((s) => s.value?.busy ?? false));
    final lockedUntil = ref.watch(provider.select((s) => s.value?.lockedUntil));
    final online = ref.watch(connectivityControllerProvider.select((s) => s.value ?? true));
    final margin = context.screenMargin;

    Future<void> send() async {
      final outcome = await ref.read(provider.notifier).send();
      if (!context.mounted) return;
      if (outcome.failure case final failure?) {
        showAppToast(context, failure.displayMessage(context.l10n));
        return;
      }
      final result = outcome.result;
      if (result == null) return;
      unawaited(HapticFeedback.mediumImpact());
      showAppToast(context, l10n.remindersSent(result.sentCount));
      final recap = ref.read(provider).value?.recap;
      if (result.skipped.isEmpty || recap == null) return;
      await showSkippedRemindersSheet(
        context,
        skipped: result.skipped,
        onWhatsApp: (s) => _openWhatsApp(context, ref, recap, s.member?.displayName ?? '', s.whatsappPhone ?? ''),
      );
    }

    final String? reason = switch ((online, count)) {
      (false, _) => l10n.needsConnection,
      (_, 0) => l10n.remindersSelectSomeone,
      _ => null,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.page,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s3, margin, AppSpace.s3),
          // Not MaxWidth: its Center would fill the whole screen height here.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.contentMax),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (lockedUntil != null) ...[
                    Center(
                      child: CountdownText(
                        until: lockedUntil,
                        prefix: l10n.remindersRetryIn,
                        showTimeOnSameDay: false,
                        onFinished: ref.watch(provider.notifier).unlock,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                  ],
                  AppButton(
                    label: l10n.remindersSend(count),
                    icon: AppIcons.bellRinging,
                    loading: busy,
                    disabledReason: reason,
                    onPressed: reason == null && lockedUntil == null && !busy ? send : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
