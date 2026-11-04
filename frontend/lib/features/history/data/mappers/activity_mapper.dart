import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';
import '../../domain/entities/activity_entry.dart';
import '../datasource/model/activity_entry_model.dart';

extension ActivityEntryModelMapper on ActivityEntryModel {
  /// The Drift row for [groupId]; null when the server sent no id or time,
  /// which the cache can't key or order.
  ActivityLogsCompanion? toCompanion(String groupId) {
    final id = this.id;
    final at = createdAt;
    if (id == null || at == null) return null;
    return ActivityLogsCompanion.insert(
      id: id,
      groupId: groupId,
      action: action ?? '',
      entityType: entityType ?? '',
      entityId: Value(entityId),
      actorId: Value(actor?.id),
      actorName: Value(actor?.name),
      actorAvatarUrl: Value(actor?.avatarUrl),
      subjectMemberId: Value(subject?.id),
      subjectDisplayName: Value(subject?.displayName),
      subjectSlotNo: Value(subject?.slotNo),
      before: Value(before),
      after: Value(after),
      createdAt: at.toUtc(),
    );
  }
}

extension ActivityLogRowMapper on ActivityLogRow {
  ActivityEntry toEntity() => ActivityEntry(
    id: id,
    groupId: groupId,
    action: action,
    entityType: entityType,
    entityId: entityId,
    actor: actorId == null && actorName == null
        ? null
        : UserSummary(id: actorId, name: actorName, avatarUrl: actorAvatarUrl),
    subject: subjectMemberId == null && subjectDisplayName == null
        ? null
        : MemberRef(id: subjectMemberId, displayName: subjectDisplayName, slotNo: subjectSlotNo),
    before: before,
    after: after,
    createdAt: createdAt,
  );
}
