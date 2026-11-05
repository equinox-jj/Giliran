import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/share_service.dart';
import '../../../../../core/services/widget_image_exporter.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/logger/app_logger.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../profile/presentation/profile/page/profile_page.dart';
import '../../../domain/entities/draw.dart';
import '../../../domain/usecases/describe_draw_result_usecase.dart';
import '../../shared/controllers/draw_controller.dart';
import '../../shared/controllers/draw_verification_provider.dart';
import '../../shared/widgets/verify_draw_sheet.dart';
import '../controllers/draw_result_view_provider.dart';
import '../widgets/reveal_sequence.dart';

/// Draw result (S38): the winner headline, the Bukti Kocok ticket, share to
/// WhatsApp / save the image, "Cek keasliannya" (S39), and the next step:
/// organizers hand over the pot ([onPayout], S40), the winner waits for it.
/// [reveal] plays the reveal sequence (right after the draw on this
/// device); later visits are static.
class const DrawResultPage({
  super.key,
  required final String groupId,
  required final String periodId,
  final bool reveal = false,
  required final VoidCallback onPayout,
  required final VoidCallback onClose,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final margin = context.screenMargin;
    final draw = ref.watch(drawControllerProvider(groupId, periodId));
    final view = ref.watch(drawResultViewProvider(groupId, periodId));
    final Widget body;
    if (draw case AsyncError(:final error)) {
      body = Padding(
        padding: EdgeInsets.all(margin),
        child: AppBanner(
          message: error is Failure ? error.displayMessage(context.l10n) : l10n.drawLoadFailed,
          variant: AppBannerVariant.error,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(drawControllerProvider(groupId, periodId)),
        ),
      );
    } else if (draw.value case final d? when view != null) {
      body = MaxWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s8),
          children: [
            _Result(groupId: groupId, periodId: periodId, draw: d, view: view, reveal: reveal),
            const SizedBox(height: AppSpace.s5),
            if (view.showHandOver)
              _NextStepCard(
                icon: AppIcons.handCoins,
                text: l10n.drawHandOver(Rupiah.format(view.potAmount), view.winnerName),
                onTap: onPayout,
              )
            else if (view.isMine)
              _NextStepCard(icon: AppIcons.money, text: l10n.drawResultMineCard, onTap: onPayout),
          ],
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator.adaptive());
    }
    return Scaffold(
      appBar: AppTopBar(onBack: onClose),
      body: body,
    );
  }
}

class const _Result({
  required final String groupId,
  required final String periodId,
  required final Draw draw,
  required final DrawResultView view,
  required final bool reveal,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);

    void verify() {
      final verification = ref.read(drawVerificationProvider(groupId, periodId));
      if (verification == null) return;
      showVerifyDrawSheet(
        context,
        draw: draw,
        verification: verification,
        onReport: () => ref
            .read(shareServiceProvider)
            .openUrl(
              ProfilePage.contactUrl.replace(queryParameters: {'subject': 'Laporan kocokan ${draw.verificationCode}'}),
            ),
      );
    }

    Future<Uint8List?> export() async {
      try {
        return await ref
            .read(widgetImageExporterProvider)
            .export(
              BuktiKocokExportFrame(
                ticket: _Ticket(draw: draw, view: view),
              ),
              logicalSize: BuktiKocokExportFrame.size,
              pixelRatio: BuktiKocokExportFrame.pixelRatio,
              inherit: context,
            );
      } on Exception catch (e, st) {
        AppLogger.w('Ticket export failed', tag: 'draw', error: e, stackTrace: st);
        if (context.mounted) showAppToast(context, l10n.drawExportFailed);
        return null;
      }
    }

    Future<void> share({required bool withText}) async {
      final png = await export();
      if (png == null) return;
      await ref
          .read(shareServiceProvider)
          .shareImage(
            png,
            text: withText
                ? l10n.drawShareMessage(view.groupName, view.periodNo, view.winnerName, draw.verifyUrl ?? '')
                : null,
          );
    }

    final paid = draw.paidCountAtDraw;
    final total = draw.totalCountAtDraw;
    return RevealSequence(
      play: reveal,
      slip: Center(child: Doodle(AppDoodles.slip, size: 72, color: c.textSecondary)),
      winner: Column(
        children: [
          const SizedBox(height: AppSpace.s3),
          AppAvatar(name: view.winnerName, size: 80, tone: c.toneFor(groupId)),
          const SizedBox(height: AppSpace.s4),
          HeadlineText(
            view.isMine ? l10n.drawResultHeadlineMine : l10n.drawResultHeadline(view.winnerName, view.periodNo),
            textAlign: TextAlign.center,
          ),
          if (paid != null && total != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(l10n.drawResultPaidAtDraw(paid, total), style: t.caption.copyWith(color: c.textSecondary)),
          ],
          const SizedBox(height: AppSpace.s5),
        ],
      ),
      ticket: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Ticket(draw: draw, view: view, onTap: verify),
          const SizedBox(height: AppSpace.s5),
          AppButton(
            label: l10n.drawShareWhatsApp,
            icon: AppIcons.whatsappLogo,
            onPressed: () => share(withText: true),
          ),
          const SizedBox(height: AppSpace.s3),
          AppButton.secondary(label: l10n.drawSaveImage, icon: AppIcons.image, onPressed: () => share(withText: false)),
          const SizedBox(height: AppSpace.s2),
          AppButton.ghost(label: l10n.drawVerifyButton, icon: AppIcons.sealCheck, onPressed: verify),
        ],
      ),
    );
  }
}

/// The Bukti Kocok ticket for [draw], on screen and in the exported image.
class const _Ticket({required final Draw draw, required final DrawResultView view, final VoidCallback? onTap})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BuktiKocokTicket(
    groupName: view.groupName,
    periodNo: view.periodNo,
    totalPeriods: view.totalPeriods,
    slotNo: view.slotNo,
    winnerName: view.winnerName,
    drawnAt: draw.drawnAt ?? DateTime.now(),
    code: draw.verificationCode ?? '',
    verifyUrl: draw.verifyUrl ?? '',
    onTap: onTap,
  );
}

class const _NextStepCard({required final String icon, required final String text, required final VoidCallback onTap})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return AppCard(
      onTap: onTap,
      semanticLabel: text,
      child: Row(
        children: [
          AppIcon(icon, color: c.textPrimary),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Text(text, style: t.label.copyWith(color: c.textPrimary)),
          ),
          AppIcon(AppIcons.caretRight, color: c.textSecondary),
        ],
      ),
    );
  }
}
