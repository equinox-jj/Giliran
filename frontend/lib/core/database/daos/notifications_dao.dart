import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/groups_table.dart';
import '../tables/notifications_table.dart';

part 'notifications_dao.g.dart';

/// A stored notification with the cached name of its group, if any.
typedef NotificationWithGroup = ({NotificationRow row, String? groupName});

/// Reads and writes the device's [Notifications], newest first, joined
/// with the cached group name for the Aktivitas tab.
@DriftAccessor(tables: [Notifications, Groups])
class NotificationsDao(super.attachedDatabase) extends DatabaseAccessor<AppDatabase> with _$NotificationsDaoMixin {
  /// How many notifications the device keeps.
  static const maxRows = 300;

  Stream<List<NotificationWithGroup>> watchAll() {
    final query = select(notifications).join([
      leftOuterJoin(groups, groups.id.equalsExp(notifications.groupId)),
    ])..orderBy([OrderingTerm.desc(notifications.createdAt), OrderingTerm.desc(notifications.id)]);
    return query.watch().map(
      (rows) => [for (final r in rows) (row: r.readTable(notifications), groupName: r.readTableOrNull(groups)?.name)],
    );
  }

  /// Stores [row] unless a notification with its id is already kept (the
  /// background handler and the tap can both see one message), then trims
  /// to the newest [maxRows].
  Future<void> insertIfAbsent(NotificationsCompanion row) => transaction(() async {
    await into(notifications).insert(row, mode: InsertMode.insertOrIgnore);
    await customUpdate(
      'DELETE FROM notifications WHERE id NOT IN '
      '(SELECT id FROM notifications ORDER BY created_at DESC, id DESC LIMIT ?1)',
      variables: [Variable.withInt(maxRows)],
      updates: {notifications},
      updateKind: UpdateKind.delete,
    );
  });

  Future<void> markRead(String id) =>
      (update(notifications)..where((n) => n.id.equals(id))).write(const NotificationsCompanion(read: Value(true)));

  Future<void> markAllRead() => (update(
    notifications,
  )..where((n) => n.read.equals(false))).write(const NotificationsCompanion(read: Value(true)));
}
