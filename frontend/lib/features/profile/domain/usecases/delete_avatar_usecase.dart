import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../repository/profile_repository.dart';

part 'delete_avatar_usecase.g.dart';

class DeleteAvatarUseCase(
  final ProfileRepository _profile,
  final AuthRepository _auth,
) implements UseCase<Unit, NoParams> {
  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    final result = await _profile.deleteAvatar();
    if (result.isRight()) {
      final cached = await _auth.readCurrentUser();
      if (cached case Right(value: final user?)) {
        await _auth.saveCurrentUser(user.copyWith(avatarUrl: null));
      }
    }
    return result;
  }
}

@Riverpod(keepAlive: true)
DeleteAvatarUseCase deleteAvatarUseCase(Ref ref) => DeleteAvatarUseCase(
  ref.watch(profileRepositoryProvider),
  ref.watch(authRepositoryProvider),
);
