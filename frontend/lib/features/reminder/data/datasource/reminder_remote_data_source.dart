import '../../../../core/network/idempotency.dart';
import 'model/recap_model.dart';
import 'model/reminder_result_model.dart';

/// The recap and reminder endpoints. Both need a connection, so nothing
/// here is cached.
abstract interface class ReminderRemoteDataSource() {
  Future<RecapModel> getRecap(String groupId, String periodId);

  /// Pushes a reminder to [memberIds], or to every unpaid member when null.
  Future<ReminderResultModel> sendReminders(
    String groupId,
    String periodId, {
    List<String>? memberIds,
    required IdempotencyKey key,
  });
}
