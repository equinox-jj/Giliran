import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../entity/session.dart';
import '../repository/profile_repository.dart';

part 'revoke_other_sessions_usecase.g.dart';

/// "Keluar dari semua perangkat lain": revokes every session in [sessions]
/// except the current one and returns how many were revoked. Stops at the
/// first failure; the sessions revoked before it stay revoked.
class RevokeOtherSessionsUseCase(final ProfileRepository _profile) implements UseCase<int, List<Session>> {
  @override
  Future<Either<Failure, int>> call(List<Session> sessions) async {
    var revoked = 0;
    for (final session in sessions) {
      final id = session.id;
      if (session.isCurrent == true || id == null) continue;
      final result = await _profile.revokeSession(id);
      if (result case Left(:final value)) return Left(value);
      revoked++;
    }
    return Right(revoked);
  }
}

@Riverpod(keepAlive: true)
RevokeOtherSessionsUseCase revokeOtherSessionsUseCase(Ref ref) =>
    RevokeOtherSessionsUseCase(ref.watch(profileRepositoryProvider));
