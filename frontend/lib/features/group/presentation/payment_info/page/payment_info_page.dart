import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/banks.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../core/utils/enums/member_role.dart';
import '../../../../../core/utils/input_formatters.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/entities/group_input.dart';
import '../controllers/payment_info_controller.dart';
import '../widgets/bank_picker_sheet.dart';

/// Payment info (S15). The organizer edits the bank account and QRIS;
/// everyone else (co-organizers included) sees them read-only.
class const PaymentInfoPage({super.key, required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = paymentInfoControllerProvider(groupId);
    final phase = ref.watch(
      provider.select(
        (s) => switch (s.value) {
          final v? => v.group.myRole == MemberRole.organizer ? _Phase.edit : _Phase.readOnly,
          null => s.hasError ? _Phase.error : _Phase.loading,
        },
      ),
    );
    return Scaffold(
      // S15 draws the organizer's form with a back button only.
      appBar: AppTopBar(title: phase == _Phase.edit ? null : l10n.paymentInfoTitle),
      body: switch (phase) {
        _Phase.loading => const Center(child: CircularProgressIndicator.adaptive()),
        _Phase.error => EmptyState(
          title: l10n.groupNotFoundTitle,
          message: l10n.homeLoadErrorMessage,
          primaryLabel: l10n.commonRetry,
          onPrimary: () => ref.invalidate(provider),
        ),
        _Phase.readOnly => _ReadOnlyInfo(provider: provider),
        _Phase.edit => _PaymentInfoForm(provider: provider),
      },
    );
  }
}

enum _Phase() {
  loading,
  error,
  readOnly,
  edit,
}

class const _ReadOnlyInfo({required final PaymentInfoControllerProvider provider}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final info = ref.watch(provider.select((s) => s.value?.group.paymentInfo)) ?? const PaymentInfo();
    return MaxWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
        children: [
          HeadlineText(l10n.paymentInfoReadOnlyHeadline),
          const SizedBox(height: AppSpace.s6),
          BankAccountCard(info: info),
          const _QrisHeader(optional: false),
          if (info.hasQris)
            QrisCard(
              hasQris: true,
              imageUrl: info.qrisImageUrl,
              merchantName: info.qrisMerchantName,
            )
          else
            Text(l10n.noQrisYet, style: t.body.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class const _PaymentInfoForm({required final PaymentInfoControllerProvider provider}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PaymentInfoForm> createState() => _PaymentInfoFormState();
}

class _PaymentInfoFormState() extends ConsumerState<_PaymentInfoForm> {
  late final TextEditingController _bankLabel;
  late final TextEditingController _otherBank;
  late final TextEditingController _number;
  late final TextEditingController _holder;
  String? _bank;
  var _otherSelected = false;

  @override
  void initState() {
    super.initState();
    final info = ref.read(widget.provider).value?.group.paymentInfo;
    final bank = info?.bankName;
    _otherSelected = bank != null && bank.isNotEmpty && !Banks.all.contains(bank);
    _bank = _otherSelected ? null : bank;
    _bankLabel = TextEditingController(text: _bank ?? '');
    _otherBank = TextEditingController(text: _otherSelected ? bank : '');
    _number = TextEditingController(
      text: CodeFormatter.grouped((info?.accountNumber ?? '').replaceAll(RegExp(r'\D'), '')),
    );
    _holder = TextEditingController(text: info?.accountHolder ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Lainnya" is localized, so its label is set once the locale is known.
    if (_otherSelected) _bankLabel.text = context.l10n.bankOther;
  }

  @override
  void dispose() {
    _bankLabel.dispose();
    _otherBank.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final picked = await showAppSheet<String>(
      context,
      tall: true,
      builder: (_) => BankPickerSheet(selected: _bank),
    );
    if (picked == null) return;
    final other = picked == BankPickerSheet.other;
    setState(() {
      _otherSelected = other;
      _bank = other ? null : picked;
      _bankLabel.text = other ? context.l10n.bankOther : picked;
    });
  }

  PaymentInfoInput get _input => PaymentInfoInput(
    bankName: _otherSelected ? _otherBank.text : (_bank ?? ''),
    accountNumber: _number.text,
    accountHolder: _holder.text,
  );

  Future<void> _save() async {
    final l10n = context.l10n;
    final group = ref.read(widget.provider).value?.group;
    final info = group?.paymentInfo ?? const PaymentInfo();
    final input = _input;
    final changed =
        info.bankName != input.bankName.trim() ||
        (info.accountNumber ?? '') != input.accountNumber.replaceAll(RegExp(r'\D'), '') ||
        (info.accountHolder ?? '') != input.accountHolder.trim();
    // Members already pay to the current account, so changing it on an
    // active group is confirmed first.
    if (group?.status == GroupStatus.active && info.hasBankAccount && changed) {
      final ok = await showConfirmationSheet(
        context,
        icon: AppIcons.bank,
        title: l10n.paymentInfoChangeTitle,
        confirmLabel: l10n.paymentInfoChangeConfirm,
        cancelLabel: l10n.commonCancel,
      );
      if (!ok || !mounted) return;
    }
    final failure = await ref.read(widget.provider.notifier).save(input);
    if (!mounted) return;
    if (failure == null) {
      showAppToast(context, l10n.paymentInfoSaved);
    } else if (failure is! ValidationFailure) {
      showAppToast(context, failure.displayMessage);
    }
  }

  Future<void> _uploadQris() async {
    final l10n = context.l10n;
    final outcome = await ref.read(widget.provider.notifier).uploadQris();
    if (!mounted) return;
    switch (outcome) {
      case QrisUploadOutcome.denied:
        showAppToast(context, l10n.photoGalleryDenied);
      case QrisUploadOutcome.failed:
        showAppToast(context, l10n.homeLoadErrorMessage);
      case QrisUploadOutcome.uploaded || QrisUploadOutcome.cancelled || QrisUploadOutcome.rejected:
        break;
    }
  }

  Future<void> _removeQris() async {
    final failure = await ref.read(widget.provider.notifier).removeQris();
    if (failure != null && mounted) showAppToast(context, failure.displayMessage);
  }

  static const _fieldGap = 18.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = AppTextStyles.of(context);
    final state = ref.watch(widget.provider).value;
    if (state == null) return const SizedBox.shrink();
    final failure = state.saveFailure;
    final info = state.group.paymentInfo ?? const PaymentInfo();
    String? error(String field, String fallback) {
      final message = failure?.fieldMessage(field);
      if (message == null) return null;
      return message.isEmpty ? fallback : message;
    }

    final qrisError = state.qrisError;
    return Column(
      children: [
        Expanded(
          child: MaxWidth(
            child: ListView(
              padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s6),
              children: [
                HeadlineText(l10n.paymentInfoHeadline),
                const SizedBox(height: AppSpace.s4),
                AppBanner(message: l10n.paymentInfoTrust, icon: AppIcons.shieldCheck, note: true),
                const SizedBox(height: AppSpace.s6),
                AppTextField(
                  label: l10n.bankLabel,
                  hint: l10n.bankHint,
                  controller: _bankLabel,
                  readOnly: true,
                  onTap: _pickBank,
                  errorText: _otherSelected ? null : error('bank_name', l10n.requiredError),
                  style: t.bodyLg.copyWith(fontWeight: FontWeight.w600),
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpace.s3),
                    child: AppIcon(AppIcons.caretDown, size: AppSizes.iconMd, color: context.colors.textSecondary),
                  ),
                ),
                if (_otherSelected) ...[
                  const SizedBox(height: _fieldGap),
                  AppTextField(
                    label: l10n.bankOtherLabel,
                    controller: _otherBank,
                    errorText: error('bank_name', l10n.requiredError),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
                const SizedBox(height: _fieldGap),
                AppTextField(
                  label: l10n.accountNumberLabel,
                  controller: _number,
                  style: t.bodyLg.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [DigitGroupingFormatter()],
                  errorText: error('account_number', l10n.accountNumberError),
                ),
                const SizedBox(height: _fieldGap),
                AppTextField(
                  label: l10n.accountHolderLabel,
                  helper: l10n.accountHolderHelper,
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  errorText: error('account_holder', l10n.requiredError),
                ),
                const _QrisHeader(),
                QrisCard(
                  inline: true,
                  hasQris: info.hasQris,
                  imageUrl: info.qrisImageUrl,
                  merchantName: info.qrisMerchantName,
                  uploading: state.uploadingQris,
                  onUpload: _uploadQris,
                  onRemove: info.hasQris ? _removeQris : null,
                  errorText: qrisError == null ? null : (qrisError.isEmpty ? l10n.qrisInvalid : qrisError),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s4),
            child: MaxWidth(
              child: AppButton(label: l10n.saveButton, block: true, loading: state.saving, onPressed: _save),
            ),
          ),
        ),
      ],
    );
  }
}

/// "QRIS", with "Opsional" at the end of the row on the organizer's form.
class const _QrisHeader({final bool optional = true}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: AppSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l10n.qrisSection, style: t.title.copyWith(color: c.textPrimary)),
            ),
          ),
          if (optional) Text(l10n.qrisOptional, style: t.caption.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}
