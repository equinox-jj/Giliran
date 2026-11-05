import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger/app_logger.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../repository/profile_repository.dart';

part 'delete_account_usecase.g.dart';

/// Deletes the account with the PIN. On success the
/// device forgets the account too: tokens, cached user, pending code and
/// the offline mirror.
class DeleteAccountUseCase(
  final ProfileRepository _profile,
  final AuthRepository _auth,
  final AppDatabase _database,
) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String pin) async {
    final result = await _profile.deleteAccount(pin);
    if (result.isLeft()) return result;

    // The account is gone on the server, so local cleanup failures are
    // logged rather than reported: there is nothing left to retry against.
    final cleared = await _auth.clearSession();
    if (cleared case Left(:final value)) {
      AppLogger.w('Session not cleared after account deletion', tag: 'profile', error: value);
    }
    try {
      await _database.clearAll();
    } on Exception catch (e, st) {
      AppLogger.w('Offline cache not cleared after account deletion', tag: 'profile', error: e, stackTrace: st);
    }
    return result;
  }
}

@Riverpod(keepAlive: true)
DeleteAccountUseCase deleteAccountUseCase(Ref ref) => DeleteAccountUseCase(
  ref.watch(profileRepositoryProvider),
  ref.watch(authRepositoryProvider),
  ref.watch(appDatabaseProvider),
);
