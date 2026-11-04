import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/push_service.dart';
import '../entities/notification_entry.dart';

/// Pushes stored on this device, and this device's FCM token on the API.
abstract interface class NotificationRepository() {
  /// Every stored notification, newest first, live.
  Stream<Either<Failure, List<NotificationEntry>>> watchNotifications();

  /// Stores [message] once (by id); received at [receivedAt] when it has no
  /// send time. Returns the stored notification's id.
  Future<Either<Failure, String>> store(PushMessage message, {required DateTime receivedAt});

  Future<Either<Failure, Unit>> markRead(String id);

  Future<Either<Failure, Unit>> markAllRead();

  /// `PUT /me/push-token` for the current session.
  Future<Either<Failure, Unit>> registerPushToken(String token);
}
