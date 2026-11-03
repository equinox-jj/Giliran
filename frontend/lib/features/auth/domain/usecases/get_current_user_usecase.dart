import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../../../profile/domain/entity/profile.dart';

part 'get_current_user_usecase.g.dart';

/// The signed-in user cached on this device, or null.
class GetCurrentUserUseCase(final AuthRepository _repository) implements UseCase<ProfileData?, NoParams> {
  @override
  Future<Either<Failure, ProfileData?>> call(NoParams params) => _repository.readCurrentUser();
}

@Riverpod(keepAlive: true)
GetCurrentUserUseCase getCurrentUserUseCase(Ref ref) => GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
