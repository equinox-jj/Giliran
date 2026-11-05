import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../domain/entities/recap.dart';
import '../../domain/entities/reminder_result.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasource/reminder_remote_data_source.dart';
import '../datasource/reminder_remote_data_source_impl.dart';
import '../mappers/reminder_mapper.dart';

part 'reminder_repository_impl.g.dart';

class ReminderRepositoryImpl(final ReminderRemoteDataSource _remote) with BaseRepository implements ReminderRepository {
  @override
  Future<Either<Failure, Recap>> getRecap(String groupId, String periodId) =>
      safeCall(() async => (await _remote.getRecap(groupId, periodId)).toEntity());

  @override
  Future<Either<Failure, ReminderResult>> sendReminders(
    String groupId,
    String periodId, {
    required List<String> memberIds,
    required IdempotencyKey key,
  }) => safeCall(
    () async => (await _remote.sendReminders(groupId, periodId, memberIds: memberIds, key: key)).toEntity(),
  );
}

@Riverpod(keepAlive: true)
ReminderRepository reminderRepository(Ref ref) => ReminderRepositoryImpl(ref.watch(reminderRemoteDataSourceProvider));
