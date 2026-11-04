import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger/app_logger.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'logout_usecase.g.dart';

/// Signs out: revokes the session on the server, then always clears the
/// device (tokens, cached user, and the offline mirror with its stored
/// notifications), so logging out still works offline and the next account
/// on this device sees none of this one's data.
class LogoutUseCase(final AuthRepository _repository, final AppDatabase _database) implements UseCase<Unit, NoParams> {
  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    // A server failure is ignored; the session expires there on its own.
    await _repository.logout();
    final cleared = await _repository.clearSession();
    try {
      await _database.clearAll();
    } on Exception catch (e, st) {
      AppLogger.w('Offline cache not cleared on sign-out', tag: 'auth', error: e, stackTrace: st);
    }
    return cleared;
  }
}

@Riverpod(keepAlive: true)
LogoutUseCase logoutUseCase(Ref ref) =>
    LogoutUseCase(ref.watch(authRepositoryProvider), ref.watch(appDatabaseProvider));
