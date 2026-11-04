import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/notifications_dao.dart';
import 'notification_local_data_source.dart';

part 'notification_local_data_source_impl.g.dart';

class NotificationLocalDataSourceImpl(final NotificationsDao _dao)
    with BaseLocalDataSource
    implements NotificationLocalDataSource {
  @override
  Stream<List<NotificationWithGroup>> watchAll() => _dao.watchAll();

  @override
  Future<void> insert(NotificationsCompanion row) => safeCacheCall(() => _dao.insertIfAbsent(row));

  @override
  Future<void> markRead(String id) => safeCacheCall(() => _dao.markRead(id));

  @override
  Future<void> markAllRead() => safeCacheCall(_dao.markAllRead);
}

@Riverpod(keepAlive: true)
NotificationLocalDataSource notificationLocalDataSource(Ref ref) =>
    NotificationLocalDataSourceImpl(ref.watch(appDatabaseProvider).notificationsDao);
