import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/entities/member_input.dart';
import 'package:giliran/features/member/domain/entities/obligation.dart';
import 'package:giliran/features/member/domain/usecases/add_guest_usecase.dart';
import 'package:giliran/features/member/domain/usecases/get_invite_preview_usecase.dart';
import 'package:giliran/features/member/domain/usecases/get_obligations_usecase.dart';
import 'package:giliran/features/member/domain/usecases/reject_leave_usecase.dart';
import 'package:giliran/features/member/domain/usecases/request_leave_usecase.dart';
import 'package:giliran/features/member/domain/usecases/save_fixed_order_usecase.dart';
import 'package:giliran/features/member/domain/usecases/update_guest_usecase.dart';

import '../../../../helpers/fake_member_repository.dart';

List<FixedOrderEntry> _order(int n) => [
  for (var i = 1; i <= n; i++) FixedOrderEntry(slotId: 'slot-$i', position: n - i + 1),
];

void main() {
  late FakeMemberRepository repository;

  setUp(() => repository = FakeMemberRepository());

  group('SaveFixedOrderUseCase', () {
    test('saves an order that covers every slot once', () async {
      // Arrange
      final useCase = SaveFixedOrderUseCase(repository);

      // Act
      final result = await useCase((groupId: 'g1', totalSlots: 3, order: _order(3)));

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.lastOrder, hasLength(3));
    });

    test('rejects an order whose length is not the slot count', () async {
      // Arrange
      final useCase = SaveFixedOrderUseCase(repository);

      // Act
      final result = await useCase((groupId: 'g1', totalSlots: 4, order: _order(3)));

      // Assert
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(repository.calls, isEmpty);
    });

    test('rejects a slot listed twice', () async {
      // Arrange
      final useCase = SaveFixedOrderUseCase(repository);
      const order = [
        FixedOrderEntry(slotId: 'slot-1', position: 1),
        FixedOrderEntry(slotId: 'slot-1', position: 2),
      ];

      // Act
      final result = await useCase((groupId: 'g1', totalSlots: 2, order: order));

      // Assert
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(repository.calls, isEmpty);
    });

    test('rejects a repeated position', () async {
      // Arrange
      final useCase = SaveFixedOrderUseCase(repository);
      const order = [
        FixedOrderEntry(slotId: 'slot-1', position: 1),
        FixedOrderEntry(slotId: 'slot-2', position: 1),
      ];

      // Act
      final result = await useCase((groupId: 'g1', totalSlots: 2, order: order));

      // Assert
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    });
  });

  group('AddGuestUseCase name bounds', () {
    for (final (name, ok) in [('A', false), ('Sr', true), ('x' * 50, true), ('x' * 51, false)]) {
      test('${name.length} characters ${ok ? 'pass' : 'fail'}', () async {
        // Arrange
        final useCase = AddGuestUseCase(repository);

        // Act
        final result = await useCase((groupId: 'g1', input: GuestInput(name: name)));

        // Assert
        expect(result.isRight(), ok);
        expect(repository.calls, ok ? ['addGuest'] : isEmpty);
      });
    }
  });

  test('UpdateGuestUseCase checks only a changed name', () async {
    // Arrange
    final useCase = UpdateGuestUseCase(repository);

    // Act
    final result = await useCase((
      groupId: 'g1',
      memberId: 'm5',
      input: const UpdateGuestInput(clearPhone: true),
    ));

    // Assert
    expect(result.isRight(), isTrue);
    expect(repository.lastGuestUpdate?.clearPhone, isTrue);
  });

  test('RequestLeaveUseCase leaves out a blank reason', () async {
    // Arrange
    final useCase = RequestLeaveUseCase(repository);

    // Act
    await useCase((groupId: 'g1', reason: '   '));

    // Assert
    expect(repository.calls, ['requestLeave']);
    expect(repository.lastReason, isNull);
  });

  test('RequestLeaveUseCase rejects a reason over 500 characters', () async {
    // Arrange
    final useCase = RequestLeaveUseCase(repository);

    // Act
    final result = await useCase((groupId: 'g1', reason: 'x' * 501));

    // Assert
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(repository.calls, isEmpty);
  });

  test('RejectLeaveUseCase rejects a reason under 3 characters', () async {
    // Arrange
    final useCase = RejectLeaveUseCase(repository);

    // Act
    final result = await useCase((groupId: 'g1', requestId: 'r1', reason: 'no'));

    // Assert
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
  });

  test('GetInvitePreviewUseCase normalizes the code', () async {
    // Arrange
    final useCase = GetInvitePreviewUseCase(repository);

    // Act
    await useCase(' k7p2qx9m ');

    // Assert
    expect(repository.calls, ['getInvitePreview:K7P2QX9M']);
  });

  test('GetObligationsUseCase puts overdue members first', () async {
    // Arrange
    repository.obligations = const [
      Obligation(member: MemberRef(id: 'a'), wonPeriodNo: 1, overdueCount: 0),
      Obligation(member: MemberRef(id: 'b'), wonPeriodNo: 3, overdueCount: 1),
      Obligation(member: MemberRef(id: 'c'), wonPeriodNo: 2, overdueCount: 2),
    ];
    final useCase = GetObligationsUseCase(repository);

    // Act
    final result = await useCase('g1');

    // Assert
    expect(result.getOrElse((_) => []).map((o) => o.memberId), ['c', 'b', 'a']);
  });
}
