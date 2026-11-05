import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/payment_status.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../domain/entities/payment.dart';
import '../controllers/upload_proof_controller.dart';

/// Opens Upload proof (S34) for my [payment] in period [periodNo]. Resolves
/// to true when the proof was sent; the caller shows the success toast.
Future<bool> showUploadProofSheet(
  BuildContext context, {
  required GroupDetail group,
  required Payment payment,
  required int periodNo,
}) async {
  final sent = await showAppSheet<bool>(
    context,
    tall: true,
    builder: (context) => _UploadProofSheet(group: group, payment: payment, periodNo: periodNo),
  );
  return sent ?? false;
}

class const _UploadProofSheet({
  required final GroupDetail group,
  required final Payment payment,
  required final int periodNo,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = uploadProofControllerProvider(group.id ?? '', payment.id ?? '');
    final state = ref.watch(provider);
    final online = ref.watch(connectivityControllerProvider.select((s) => s.value ?? true));
    final controller = ref.watch(provider.notifier);
    final amount = Rupiah.format(payment.amount ?? group.amount ?? 0);
    final info = group.paymentInfo ?? const PaymentInfo();

    Future<void> submit() async {
      final sent = await controller.submit();
      if (!sent || !context.mounted) return;
      await HapticFeedback.mediumImpact();
      if (context.mounted) Navigator.of(context).pop(true);
    }

    final String? disabledReason = switch (state) {
      _ when !online => l10n.needsConnection,
      UploadProofState(path: null) => l10n.uploadProofPickFirst,
      UploadProofState(confirmed: false) => l10n.uploadProofCheckFirst,
      _ => null,
    };

    return AppSheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.uploadProofTitle(periodNo), style: t.title.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(amount, style: t.amountXl.copyWith(color: c.textPrimary)),
          if (payment.status == PaymentStatus.rejected) ...[
            const SizedBox(height: AppSpace.s4),
            AppBanner(
              variant: AppBannerVariant.error,
              message: l10n.uploadProofRejected(payment.rejectReason ?? ''),
            ),
          ],
          SectionHeader(title: l10n.uploadProofTransferTo, top: AppSpace.s5),
          if (info.hasBankAccount)
            BankAccountCard(info: info)
          else
            Text(l10n.uploadProofNoAccount, style: t.body.copyWith(color: c.textSecondary)),
          if (info.hasQris) _QrisSection(info: info),
          const SizedBox(height: AppSpace.s5),
          Text(l10n.uploadProofSteps, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.s4),
          UploadTile(
            localPath: state.path,
            progress: state.progress,
            done: state.done,
            errorText: _errorText(l10n, state),
            onPick: state.uploading ? null : controller.pick,
            onRemove: controller.remove,
            onRetry: state.path == null || !online ? null : submit,
          ),
          const SizedBox(height: AppSpace.s4),
          CheckRow(
            label: l10n.uploadProofConfirm(amount),
            value: state.confirmed,
            onChanged: state.uploading ? null : controller.setConfirmed,
          ),
          const SizedBox(height: AppSpace.s5),
          AppButton(
            label: l10n.uploadProofSubmit,
            block: true,
            loading: state.uploading,
            disabledReason: disabledReason,
            onPressed: state.canSubmit && online ? submit : null,
          ),
        ],
      ),
    );
  }

  static String? _errorText(AppLocalizations l10n, UploadProofState state) {
    if (state.denied) return l10n.uploadPermissionDenied;
    final failure = state.failure;
    if (failure == null) return null;
    return switch (failure.apiCode) {
      ApiErrorCode.fileTooLarge => l10n.uploadTooLarge,
      ApiErrorCode.unsupportedMediaType => l10n.uploadUnsupported,
      _ => failure.displayMessage(l10n),
    };
  }
}

/// "Bayar pakai QRIS", collapsed until tapped.
class const _QrisSection({required final PaymentInfo info}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpace.s2),
        title: Text(context.l10n.uploadProofQris, style: t.label.copyWith(color: c.textPrimary)),
        children: [
          QrisCard(hasQris: true, imageUrl: info.qrisImageUrl, merchantName: info.qrisMerchantName),
        ],
      ),
    );
  }
}
