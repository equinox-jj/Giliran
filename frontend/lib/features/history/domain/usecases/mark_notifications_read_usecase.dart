import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../repositories/notification_repository.dart';

part 'mark_notifications_read_usecase.g.dart';

/// Marks one notification read (by id), or all of them when the id is null
/// ("Tandai semua dibaca"). Local only.
class const MarkNotificationsReadUseCase(final NotificationRepository _repository) implements UseCase<Unit, String?> {
  @override
  Future<Either<Failure, Unit>> call(String? params) =>
      params == null ? _repository.markAllRead() : _repository.markRead(params);
}

@Riverpod(keepAlive: true)
MarkNotificationsReadUseCase markNotificationsReadUseCase(Ref ref) =>
    MarkNotificationsReadUseCase(ref.watch(notificationRepositoryProvider));
