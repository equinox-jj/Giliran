import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../controllers/claim_controller.dart';

/// Claim guest slot (S29) for claim [token]: "Ini saya, ambil slot". An
/// expired or used link shows the expired empty state, and `already_member`
/// explains and offers "Buka grup". The API gives no preview before the
/// claim, so the page shows the explanation only.
class const ClaimPage({
  super.key,
  required final String token,
  required final ValueChanged<String?> onClaimed,
  required final VoidCallback onClose,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState() extends ConsumerState<ClaimPage> {
  Failure? _failure;

  Future<void> _claim() async {
    final outcome = await ref.read(claimControllerProvider(widget.token).notifier).claim();
    if (!mounted) return;
    final failure = outcome.failure;
    if (failure == null) {
      showAppToast(context, context.l10n.claimedToast);
      widget.onClaimed(outcome.groupId);
      return;
    }
    final known = failure.apiCode == ApiErrorCode.claimNotFound || failure.apiCode == ApiErrorCode.alreadyMember;
    if (known) {
      setState(() => _failure = failure);
    } else {
      showAppToast(context, failure.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final claiming = ref.watch(claimControllerProvider(widget.token));
    final failure = _failure;
    return Scaffold(
      appBar: AppTopBar(onBack: widget.onClose),
      body: switch (failure?.apiCode) {
        ApiErrorCode.claimNotFound => EmptyState(
          illustration: const Doodle(AppDoodles.slip, size: 160),
          title: l10n.claimExpiredTitle,
          message: l10n.claimExpiredMessage,
          primaryLabel: l10n.joinLater,
          onPrimary: widget.onClose,
        ),
        ApiErrorCode.alreadyMember => EmptyState(
          illustration: const Doodle(AppDoodles.hands, size: 160),
          title: l10n.claimAlreadyMember,
          primaryLabel: l10n.joinOpenGroup,
          onPrimary: () => widget.onClaimed(null),
        ),
        _ => MaxWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
            children: [
              const Center(child: Doodle(AppDoodles.hands, size: 160)),
              const SizedBox(height: AppSpace.s4),
              HeadlineText(l10n.claimHeadline),
              const SizedBox(height: AppSpace.s3),
              Text(l10n.claimBody, style: t.bodyLg.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpace.s8),
              AppButton(label: l10n.claimButton, block: true, loading: claiming, onPressed: _claim),
              const SizedBox(height: AppSpace.s2),
              AppButton.ghost(label: l10n.joinLater, block: true, onPressed: widget.onClose),
            ],
          ),
        ),
      },
    );
  }
}
