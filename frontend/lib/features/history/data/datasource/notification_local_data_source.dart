import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/notifications_dao.dart';

/// Pushes stored on this device.
abstract interface class NotificationLocalDataSource() {
  Stream<List<NotificationWithGroup>> watchAll();

  Future<void> insert(NotificationsCompanion row);

  Future<void> markRead(String id);

  Future<void> markAllRead();
}
