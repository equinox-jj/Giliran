import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/history/domain/entities/notification_entry.dart';
import 'package:giliran/features/history/domain/usecases/resolve_notification_target_usecase.dart';

void main() {
  const resolve = ResolveNotificationTargetUseCase();

  NotificationTarget target(PushKind kind, {String? gid = 'g1', String? pid = 'p1', String? payId = 'pay1'}) =>
      resolve((kind: kind, groupId: gid, periodId: pid, paymentId: payId));

  final table = <PushKind, NotificationTarget>{
    PushKind.drawCompleted: const DrawResultTarget('g1', 'p1'),
    PushKind.proofUploaded: const ProofReviewTarget('g1', 'pay1'),
    PushKind.payoutRecorded: const PayoutTarget('g1', 'p1'),
    PushKind.paymentReminder: const GroupTarget('g1', tab: GroupTargetTab.payments),
    PushKind.paymentApproved: const GroupTarget('g1', tab: GroupTargetTab.payments),
    PushKind.paymentRejected: const GroupTarget('g1', tab: GroupTargetTab.payments),
    PushKind.paymentMarkedPaid: const GroupTarget('g1', tab: GroupTargetTab.payments),
    PushKind.obligationsMissed: const GroupTarget('g1', tab: GroupTargetTab.members),
    PushKind.unknown: const GroupTarget('g1'),
  };

  for (final MapEntry(key: kind, value: expected) in table.entries) {
    test('${kind.name} opens ${expected.runtimeType}', () {
      // Act
      final t = target(kind);

      // Assert
      expect(_describe(t), _describe(expected));
    });
  }

  test('a draw push without a period falls back to its group', () {
    // Act
    final t = target(PushKind.drawCompleted, pid: null);

    // Assert
    expect(_describe(t), _describe(const GroupTarget('g1')));
  });

  test('a proof push without a payment opens the Pembayaran tab', () {
    // Act
    final t = target(PushKind.proofUploaded, payId: null);

    // Assert
    expect(_describe(t), _describe(const GroupTarget('g1', tab: GroupTargetTab.payments)));
  });

  test('a push without a group opens the Aktivitas tab', () {
    // Act
    final t = target(PushKind.paymentReminder, gid: null);

    // Assert
    expect(t, isA<InboxTarget>());
  });
}

/// Targets have no `==`; compare their type and ids.
String _describe(NotificationTarget t) => switch (t) {
  InboxTarget() => 'inbox',
  GroupTarget(:final groupId, :final tab) => 'group:$groupId:$tab',
  ProofReviewTarget(:final groupId, :final paymentId) => 'proof:$groupId:$paymentId',
  DrawResultTarget(:final groupId, :final periodId) => 'draw:$groupId:$periodId',
  PayoutTarget(:final groupId, :final periodId) => 'payout:$groupId:$periodId',
};
