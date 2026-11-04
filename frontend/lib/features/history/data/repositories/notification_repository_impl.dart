import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/services/push_service.dart';
import '../../domain/entities/notification_entry.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasource/notification_local_data_source.dart';
import '../datasource/notification_local_data_source_impl.dart';
import '../datasource/notification_remote_data_source.dart';
import '../datasource/notification_remote_data_source_impl.dart';
import '../mappers/notification_mapper.dart';

part 'notification_repository_impl.g.dart';

class NotificationRepositoryImpl(final NotificationRemoteDataSource _remote, final NotificationLocalDataSource _local)
    with BaseRepository
    implements NotificationRepository {
  @override
  Stream<Either<Failure, List<NotificationEntry>>> watchNotifications() =>
      safeStream(_local.watchAll().map((rows) => [for (final r in rows) r.toEntity()]));

  @override
  Future<Either<Failure, String>> store(PushMessage message, {required DateTime receivedAt}) => safeCall(() async {
    final row = message.toCompanion(receivedAt: receivedAt);
    await _local.insert(row);
    return row.id.value;
  });

  @override
  Future<Either<Failure, Unit>> markRead(String id) => safeCall(() async {
    await _local.markRead(id);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> markAllRead() => safeCall(() async {
    await _local.markAllRead();
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> registerPushToken(String token) => safeCall(() async {
    await _remote.putPushToken(token);
    return unit;
  });
}

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) => NotificationRepositoryImpl(
  ref.watch(notificationRemoteDataSourceProvider),
  ref.watch(notificationLocalDataSourceProvider),
);
