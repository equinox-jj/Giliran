import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/notifications_dao.dart';
import '../../../../core/services/push_service.dart';
import '../../domain/entities/notification_entry.dart';

extension PushMessageMapper on PushMessage {
  /// The row for this push. Without an FCM id, the payload itself keys it,
  /// so the same message stored twice stays one row.
  NotificationsCompanion toCompanion({required DateTime receivedAt}) => NotificationsCompanion.insert(
    id: id ?? 'local-${toPayload().hashCode.toUnsigned(32)}',
    type: data['type'] ?? '',
    groupId: Value(data['group_id']),
    periodId: Value(data['period_id']),
    paymentId: Value(data['payment_id']),
    payoutId: Value(data['payout_id']),
    title: Value(title),
    body: Value(body),
    createdAt: (sentAt ?? receivedAt).toUtc(),
  );
}

extension NotificationWithGroupMapper on NotificationWithGroup {
  NotificationEntry toEntity() => NotificationEntry(
    id: row.id,
    kind: PushKind.fromApi(row.type),
    groupId: row.groupId,
    groupName: groupName,
    periodId: row.periodId,
    paymentId: row.paymentId,
    payoutId: row.payoutId,
    title: row.title,
    body: row.body,
    createdAt: row.createdAt,
    read: row.read,
  );
}
