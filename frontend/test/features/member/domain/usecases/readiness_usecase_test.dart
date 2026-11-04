import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/entities/readiness.dart';
import 'package:giliran/features/member/domain/usecases/build_readiness_usecase.dart';
import 'package:giliran/features/member/domain/usecases/sort_by_fixed_order_usecase.dart';

void main() {
  const build = BuildReadinessUseCase();

  test('a full fixed-order group with an account and positions is ready', () {
    // Arrange
    const group = GroupDetail(
      totalSlots: 2,
      filledSlots: 2,
      drawMethod: DrawMethod.fixedOrder,
      paymentInfo: PaymentInfo(accountNumber: '1234567890'),
    );
    const members = [Member(fixedOrderPosition: 1), Member(fixedOrderPosition: 2)];

    // Act
    final items = build((group: group, members: members));

    // Assert
    expect(items.map((i) => i.kind), [ReadinessKind.slots, ReadinessKind.paymentInfo, ReadinessKind.fixedOrder]);
    expect(items.every((i) => i.done), isTrue);
  });

  test('a member without a position leaves the order incomplete', () {
    // Arrange
    const group = GroupDetail(totalSlots: 2, filledSlots: 2, drawMethod: DrawMethod.fixedOrder);
    const members = [Member(fixedOrderPosition: 1), Member()];

    // Act
    final items = build((group: group, members: members));

    // Assert
    expect(items.last.done, isFalse);
    expect(items[1].done, isFalse);
  });

  test('each start conflict names its item', () {
    // Act
    final kinds = [
      BuildReadinessUseCase.kindFor(ApiErrorCode.slotsNotFilled),
      BuildReadinessUseCase.kindFor(ApiErrorCode.paymentInfoMissing),
      BuildReadinessUseCase.kindFor(ApiErrorCode.fixedOrderIncomplete),
      BuildReadinessUseCase.kindFor(ApiErrorCode.groupNotDraft),
    ];

    // Assert
    expect(kinds, [ReadinessKind.slots, ReadinessKind.paymentInfo, ReadinessKind.fixedOrder, null]);
  });

  test('members without a position sort last by slot', () {
    // Arrange
    const members = [
      Member(id: 'a', slotNo: 1),
      Member(id: 'b', slotNo: 2, fixedOrderPosition: 2),
      Member(id: 'c', slotNo: 3, fixedOrderPosition: 1),
    ];

    // Act
    final sorted = const SortByFixedOrderUseCase()(members);

    // Assert
    expect(sorted.map((m) => m.id), ['c', 'b', 'a']);
  });
}
