import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../entity/session.dart';
import '../repository/profile_repository.dart';

part 'get_sessions_usecase.g.dart';

/// The account's active devices, current one first.
class GetSessionsUseCase(final ProfileRepository _profile) implements UseCase<List<Session>, NoParams> {
  @override
  Future<Either<Failure, List<Session>>> call(NoParams params) => _profile.getSessions();
}

@Riverpod(keepAlive: true)
GetSessionsUseCase getSessionsUseCase(Ref ref) => GetSessionsUseCase(ref.watch(profileRepositoryProvider));
