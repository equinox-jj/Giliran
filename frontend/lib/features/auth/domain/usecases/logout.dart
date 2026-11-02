import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'logout.g.dart';

/// Signs out: revokes the session on the server, then always clears the
/// device, so logging out still works offline.
class Logout(final AuthRepository _repository) implements UseCase<Unit, NoParams> {
  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    // A server failure is ignored; the session expires there on its own.
    await _repository.logout();
    return _repository.clearSession();
  }
}

@riverpod
Logout logout(Ref ref) => Logout(ref.watch(authRepositoryProvider));
