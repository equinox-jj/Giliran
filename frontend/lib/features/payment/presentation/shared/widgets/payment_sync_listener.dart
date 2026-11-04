import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../controllers/payment_sync_controller.dart';

/// Keeps [PaymentSyncController] running for the signed-in shell and tells
/// the user when the server refused an offline cash mark ("Perubahan tidak
/// tersimpan: …").
class const PaymentSyncListener({super.key, required final Widget child}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(paymentSyncControllerProvider, (_, report) {
      if (report == null || report.rejected.isEmpty) return;
      showAppToast(context, context.l10n.paymentSyncRejected);
    });
    return child;
  }
}
