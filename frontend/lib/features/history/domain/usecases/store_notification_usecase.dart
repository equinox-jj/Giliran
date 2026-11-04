import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/clock.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../repositories/notification_repository.dart';

part 'store_notification_usecase.g.dart';

/// Keeps a received push for the Aktivitas tab and returns its id. Pushes
/// without a `type` are not ours (FCM console tests): they are skipped and
/// give null.
class const StoreNotificationUseCase(final NotificationRepository _repository, final DateTime Function() _now)
    implements UseCase<String?, PushMessage> {
  @override
  Future<Either<Failure, String?>> call(PushMessage params) async {
    if ((params.data['type'] ?? '').isEmpty) return const Right(null);
    return _repository.store(params, receivedAt: _now());
  }
}

@Riverpod(keepAlive: true)
StoreNotificationUseCase storeNotificationUseCase(Ref ref) =>
    StoreNotificationUseCase(ref.watch(notificationRepositoryProvider), ref.watch(clockProvider));
