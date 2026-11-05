import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/payment_status.dart';
import '../entities/payment.dart';

part 'sort_payment_board_usecase.g.dart';

/// The organizer filter chips on the Pembayaran tab.
enum PaymentBoardFilter() {
  all,

  /// Belum bayar: unpaid or rejected.
  unpaid,

  /// Menunggu cek: a proof waits for review.
  pendingReview,
}

/// Orders a payment board: my own row pinned first, then by slot
/// number, narrowed by a filter chip. Pure and synchronous, so it does not
/// go through `UseCase`.
class const SortPaymentBoardUseCase() {
  List<Payment> call(({List<Payment> payments, PaymentBoardFilter filter}) params) {
    final rows = [
      for (final p in params.payments)
        if (_matches(p, params.filter)) p,
    ];
    rows.sort((a, b) {
      if (a.mine != b.mine) return a.mine ? -1 : 1;
      return (a.member?.slotNo ?? 0).compareTo(b.member?.slotNo ?? 0);
    });
    return rows;
  }

  static bool _matches(Payment p, PaymentBoardFilter filter) => switch (filter) {
    PaymentBoardFilter.all => true,
    PaymentBoardFilter.unpaid => p.status == PaymentStatus.unpaid || p.status == PaymentStatus.rejected,
    PaymentBoardFilter.pendingReview => p.status == PaymentStatus.pendingReview,
  };
}

@Riverpod(keepAlive: true)
SortPaymentBoardUseCase sortPaymentBoardUseCase(Ref ref) => const SortPaymentBoardUseCase();
