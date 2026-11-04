import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../repositories/notification_repository.dart';

part 'register_push_token_usecase.g.dart';

/// Saves this device's FCM token on the current session, so the worker can
/// push to it. Called on sign-in and on every token refresh.
class const RegisterPushTokenUseCase(final NotificationRepository _repository) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String params) async {
    final token = params.trim();
    if (token.isEmpty) return const Left(Failure.validation());
    return _repository.registerPushToken(token);
  }
}

@Riverpod(keepAlive: true)
RegisterPushTokenUseCase registerPushTokenUseCase(Ref ref) =>
    RegisterPushTokenUseCase(ref.watch(notificationRepositoryProvider));
