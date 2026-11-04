import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/domain/usecases/sort_payment_board_usecase.dart';

Payment _payment(String id, int slot, PaymentStatus status, {bool mine = false}) => Payment(
  id: id,
  member: MemberRef(slotNo: slot),
  status: status,
  isMine: mine,
);

void main() {
  const useCase = SortPaymentBoardUseCase();
  final payments = [
    _payment('a', 3, PaymentStatus.paid),
    _payment('b', 1, PaymentStatus.pendingReview),
    _payment('c', 5, PaymentStatus.unpaid, mine: true),
    _payment('d', 2, PaymentStatus.rejected),
  ];

  test('pins my row first, then orders by slot number', () {
    // Act
    final sorted = useCase((payments: payments, filter: PaymentBoardFilter.all));

    // Assert
    expect(sorted.map((p) => p.id), ['c', 'b', 'd', 'a']);
  });

  test('Belum bayar keeps unpaid and rejected rows', () {
    // Act
    final sorted = useCase((payments: payments, filter: PaymentBoardFilter.unpaid));

    // Assert
    expect(sorted.map((p) => p.id), ['c', 'd']);
  });

  test('Menunggu cek keeps pending rows', () {
    // Act
    final sorted = useCase((payments: payments, filter: PaymentBoardFilter.pendingReview));

    // Assert
    expect(sorted.map((p) => p.id), ['b']);
  });
}
