import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/notification_entry.dart';

part 'resolve_notification_target_usecase.g.dart';

/// Where tapping a push goes (Tikar 8.24): draw result → Bukti Kocok
/// (S38), proof uploaded → proof review (S35), payment updates and
/// reminders → the Pembayaran tab (S20), payout recorded → payout (S40),
/// a past winner's missed payment → the Anggota tab. A push without the ids
/// it needs falls back to its group, then to the Aktivitas tab. Pure and
/// synchronous, so it does not go through `UseCase`.
class const ResolveNotificationTargetUseCase() {
  NotificationTarget call(({PushKind kind, String? groupId, String? periodId, String? paymentId}) params) {
    final gid = params.groupId;
    if (gid == null || gid.isEmpty) return const InboxTarget();
    final pid = params.periodId;
    final payId = params.paymentId;
    return switch (params.kind) {
      PushKind.drawCompleted when pid != null => DrawResultTarget(gid, pid),
      PushKind.proofUploaded when payId != null => ProofReviewTarget(gid, payId),
      PushKind.payoutRecorded when pid != null => PayoutTarget(gid, pid),
      PushKind.paymentReminder ||
      PushKind.paymentApproved ||
      PushKind.paymentRejected ||
      PushKind.paymentMarkedPaid ||
      PushKind.proofUploaded => GroupTarget(gid, tab: GroupTargetTab.payments),
      PushKind.obligationsMissed => GroupTarget(gid, tab: GroupTargetTab.members),
      _ => GroupTarget(gid),
    };
  }
}

@Riverpod(keepAlive: true)
ResolveNotificationTargetUseCase resolveNotificationTargetUseCase(Ref ref) => const ResolveNotificationTargetUseCase();
