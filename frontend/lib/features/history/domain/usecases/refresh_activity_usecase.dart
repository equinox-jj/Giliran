import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../entities/activity_entry.dart';
import '../repositories/history_repository.dart';

part 'refresh_activity_usecase.g.dart';

/// Fetches the newest page of a group's activity log into the cache and
/// says where the next page starts.
class const RefreshActivityUseCase(final HistoryRepository _repository) implements UseCase<ActivityCursor, String> {
  @override
  Future<Either<Failure, ActivityCursor>> call(String params) => _repository.refreshActivity(params);
}

@Riverpod(keepAlive: true)
RefreshActivityUseCase refreshActivityUseCase(Ref ref) => RefreshActivityUseCase(ref.watch(historyRepositoryProvider));
