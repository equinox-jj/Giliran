import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../entities/notification_entry.dart';
import '../repositories/notification_repository.dart';

part 'watch_notifications_usecase.g.dart';

/// The stored notifications under an S12 filter chip, newest first, live.
class const WatchNotificationsUseCase(final NotificationRepository _repository)
    implements StreamUseCase<List<NotificationEntry>, NotificationFilter> {
  @override
  Stream<Either<Failure, List<NotificationEntry>>> call(NotificationFilter params) =>
      _repository.watchNotifications().map(
        (result) => result.map(
          (entries) => switch (params) {
            NotificationFilter.all => entries,
            NotificationFilter.unread => [
              for (final e in entries)
                if (!e.read) e,
            ],
            NotificationFilter.needsAction => [
              for (final e in entries)
                if (e.pendingAction) e,
            ],
          },
        ),
      );
}

@Riverpod(keepAlive: true)
WatchNotificationsUseCase watchNotificationsUseCase(Ref ref) =>
    WatchNotificationsUseCase(ref.watch(notificationRepositoryProvider));
