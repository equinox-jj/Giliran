import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/group/domain/entities/group_summary.dart';
import 'package:giliran/features/home/domain/entities/next_action.dart';
import 'package:giliran/features/home/domain/usecases/pick_next_action_usecase.dart';

import '../../../../helpers/group_fixtures.dart';

// 10.00 WIB on Wed 4 Nov 2026.
final _now = DateTime.utc(2026, 11, 4, 3);
final _today = DateTime.utc(2026, 11, 4);

final _rejected = summary('rejected', payment: PaymentStatus.rejected, due: DateTime.utc(2026, 11, 20));
final _dueSoon = summary('due', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 7));
final _review = summary('review', role: MemberRole.organizer, pending: 2, due: DateTime.utc(2026, 11, 20));
final _drawToday = summary('draw', role: MemberRole.organizer, due: _today);
final _won = summary('won');

NextAction? _pick(List<GroupSummary> groups, {Set<String> payouts = const {}}) =>
    const PickNextActionUseCase()((groups: groups, now: _now, payoutsToConfirm: payouts));

void main() {
  final pairs = <String, (GroupSummary, GroupSummary, Set<String>, NextActionKind)>{
    'a rejected payment beats a payment due soon': (_dueSoon, _rejected, {}, NextActionKind.paymentRejected),
    'a payment due soon beats proofs to review': (_review, _dueSoon, {}, NextActionKind.paymentDue),
    'proofs to review beat a draw today': (_drawToday, _review, {}, NextActionKind.reviewProofs),
    'a draw today beats a payout to confirm': (_won, _drawToday, {'won'}, NextActionKind.drawToday),
  };
  for (final MapEntry(key: label, value: (lower, higher, payouts, kind)) in pairs.entries) {
    test(label, () {
      // Act
      final action = _pick([lower, higher], payouts: payouts);

      // Assert
      expect(action?.kind, kind);
      expect(action?.group, higher);
    });
  }

  test('a payout to confirm shows when nothing else is urgent', () {
    // Act
    final action = _pick([_won], payouts: {'won'});

    // Assert
    expect(action?.kind, NextActionKind.confirmPayout);
  });

  test('returns null when nothing is urgent', () {
    // Arrange
    final groups = [summary('paid', due: DateTime.utc(2026, 11, 20))];

    // Act
    final action = _pick(groups);

    // Assert
    expect(action, isNull);
  });

  test('a payment due in 4 days is not urgent yet', () {
    // Arrange
    final groups = [summary('later', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 8))];

    // Act
    final action = _pick(groups);

    // Assert
    expect(action, isNull);
  });

  test('an overdue payment counts as due', () {
    // Arrange
    final groups = [summary('late', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 1))];

    // Act
    final action = _pick(groups);

    // Assert
    expect(action?.kind, NextActionKind.paymentDue);
  });

  test('the soonest due date wins within one kind', () {
    // Arrange
    final later = summary('later', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 7));
    final sooner = summary('sooner', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 5));

    // Act
    final action = _pick([later, sooner]);

    // Assert
    expect(action?.group.id, 'sooner');
  });

  test('a member sees no review or draw item', () {
    // Arrange
    final groups = [summary('m', pending: 3, due: _today)];

    // Act
    final action = _pick(groups);

    // Assert
    expect(action, isNull);
  });

  test('draft groups are ignored', () {
    // Arrange
    final groups = [
      summary('draft', status: GroupStatus.draft, payment: PaymentStatus.rejected),
    ];

    // Act
    final action = _pick(groups);

    // Assert
    expect(action, isNull);
  });

  test('carries the number of proofs to review', () {
    // Act
    final action = _pick([_review]);

    // Assert
    expect(action?.count, 2);
  });
}
