import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../entities/activity_entry.dart';
import '../repositories/history_repository.dart';

part 'watch_activity_usecase.g.dart';

/// A group's cached activity log, newest first, live.
class const WatchActivityUseCase(final HistoryRepository _repository)
    implements StreamUseCase<List<ActivityEntry>, String> {
  @override
  Stream<Either<Failure, List<ActivityEntry>>> call(String params) => _repository.watchActivity(params);
}

@Riverpod(keepAlive: true)
WatchActivityUseCase watchActivityUseCase(Ref ref) => WatchActivityUseCase(ref.watch(historyRepositoryProvider));
