import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/features/reminder/domain/entities/recap.dart';
import 'package:giliran/features/reminder/domain/entities/reminder_result.dart';
import 'package:giliran/features/reminder/domain/repositories/reminder_repository.dart';

/// Records each call, and each send with its key and member ids. A send
/// answers from [sendResults] (for retries) before [sendResult].
class FakeReminderRepository() implements ReminderRepository {
  final calls = <String>[];
  final periodIds = <String>[];
  final keys = <String>[];
  final memberIds = <List<String>>[];

  Either<Failure, Recap> recapResult = const Right(Recap());
  Either<Failure, ReminderResult> sendResult = const Right(ReminderResult());

  /// Answers for the next sends, in order, before [sendResult].
  final sendResults = <Either<Failure, ReminderResult>>[];

  @override
  Future<Either<Failure, Recap>> getRecap(String groupId, String periodId) async {
    calls.add('getRecap');
    periodIds.add(periodId);
    return recapResult;
  }

  @override
  Future<Either<Failure, ReminderResult>> sendReminders(
    String groupId,
    String periodId, {
    required List<String> memberIds,
    required IdempotencyKey key,
  }) async {
    calls.add('sendReminders');
    keys.add(key.value);
    this.memberIds.add(memberIds);
    return sendResults.isNotEmpty ? sendResults.removeAt(0) : sendResult;
  }
}
