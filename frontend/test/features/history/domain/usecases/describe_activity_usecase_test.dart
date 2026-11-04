import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/history/domain/entities/activity_description.dart';
import 'package:giliran/features/history/domain/entities/activity_entry.dart';
import 'package:giliran/features/history/domain/usecases/describe_activity_usecase.dart';
import 'package:giliran/features/member/domain/entities/member.dart';

void main() {
  const describe = DescribeActivityUseCase();
  const actor = UserSummary(id: 'u1', name: 'Bu Rina');
  const subject = MemberRef(id: 'm2', displayName: 'Pak Dedi', slotNo: 2);

  test('every backend action maps to its own kind', () {
    for (final kind in ActivityKind.values.where((k) => k != ActivityKind.unknown)) {
      // Act
      final d = describe(ActivityEntry(action: kind.api, actor: actor));

      // Assert
      expect(d.kind, kind, reason: kind.api);
    }
  });

  test('an unknown action is described, not thrown', () {
    // Act
    final d = describe(const ActivityEntry(action: 'group.teleported', actor: actor));

    // Assert
    expect(d.kind, ActivityKind.unknown);
    expect(d.actorName, 'Bu Rina');
  });

  test('a null actor is a system action', () {
    // Act
    final d = describe(const ActivityEntry(action: 'period.opened', after: {'period_no': 4}));

    // Assert
    expect(d.isSystem, isTrue);
    expect(d.periodNo, 4);
  });

  test('group.updated names only the changed fields and diffs their values', () {
    // Act
    final d = describe(
      const ActivityEntry(
        action: 'group.updated',
        actor: actor,
        before: {'name': 'Arisan', 'amount': 150000, 'total_slots': 10},
        after: {'name': 'Arisan', 'amount': 200000, 'total_slots': 12},
      ),
    );

    // Assert
    expect(d.changedFields, [ActivityField.amount, ActivityField.totalSlots]);
    expect(d.diffs.first.field, ActivityField.amount);
    expect(d.diffs.first.before, 150000);
    expect(d.diffs.first.after, 200000);
  });

  test('payment entries carry the subject, reason and method', () {
    // Act
    final rejected = describe(
      const ActivityEntry(
        action: 'payment.rejected',
        actor: actor,
        subject: subject,
        after: {'reject_reason': 'Nominal kurang'},
      ),
    );
    final marked = describe(
      const ActivityEntry(action: 'payment.marked_paid', actor: actor, subject: subject, after: {'method': 'cash'}),
    );

    // Assert
    expect(rejected.subjectName, 'Pak Dedi');
    expect(rejected.reason, 'Nominal kurang');
    expect(marked.method, PaymentMethod.cash);
  });

  test('draw.completed reads the winning slot and the paid count', () {
    // Act
    final d = describe(
      const ActivityEntry(
        action: 'draw.completed',
        actor: actor,
        after: {'winner_slot_no': 7, 'paid_count': 8, 'total_count': 10},
      ),
    );

    // Assert
    expect(d.slotNo, 7);
    expect(d.paidCount, 8);
    expect(d.totalCount, 10);
  });

  test('a payout that completed the group says so', () {
    // Act
    final d = describe(
      const ActivityEntry(
        action: 'payout.recorded',
        actor: actor,
        subject: subject,
        after: {'amount': 2000000, 'period_no': 10, 'group_status': 'completed'},
      ),
    );

    // Assert
    expect(d.amount, 2000000);
    expect(d.completedGroup, isTrue);
  });

  test('a guest added without a subject falls back to the logged name', () {
    // Act
    final d = describe(const ActivityEntry(action: 'member.guest_added', actor: actor, after: {'name': 'Mbak Sri'}));

    // Assert
    expect(d.subjectName, 'Mbak Sri');
  });
}
