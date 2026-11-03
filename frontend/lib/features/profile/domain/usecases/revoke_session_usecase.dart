import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../repository/profile_repository.dart';

part 'revoke_session_usecase.g.dart';

/// Signs out one other device by its session id.
class RevokeSessionUseCase(final ProfileRepository _profile) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String sessionId) => _profile.revokeSession(sessionId);
}

@Riverpod(keepAlive: true)
RevokeSessionUseCase revokeSessionUseCase(Ref ref) => RevokeSessionUseCase(ref.watch(profileRepositoryProvider));
