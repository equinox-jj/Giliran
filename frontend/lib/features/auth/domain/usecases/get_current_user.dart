import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../../../profile/domain/entity/profile.dart';

part 'get_current_user.g.dart';

/// The signed-in user cached on this device, or null.
class GetCurrentUser(final AuthRepository _repository) implements UseCase<ProfileData?, NoParams> {
  @override
  Future<Either<Failure, ProfileData?>> call(NoParams params) => _repository.readCurrentUser();
}

@riverpod
GetCurrentUser getCurrentUser(Ref ref) => GetCurrentUser(ref.watch(authRepositoryProvider));
