import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../entities/recap.dart';
import '../entities/reminder_result.dart';

/// A period's recap and push reminders, always fresh from the API.
abstract interface class ReminderRepository() {
  Future<Either<Failure, Recap>> getRecap(String groupId, String periodId);

  Future<Either<Failure, ReminderResult>> sendReminders(
    String groupId,
    String periodId, {
    required List<String> memberIds,
    required IdempotencyKey key,
  });
}
