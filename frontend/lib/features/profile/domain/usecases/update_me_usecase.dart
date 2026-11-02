import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../entity/profile.dart';
import '../repository/profile_repository.dart';

part 'update_me_usecase.g.dart';

typedef UpdateMeParams = ({String? name, String? phone});

/// Saves the name and the optional WhatsApp number (S05, S43), then caches
/// the updated user so the launch gate stops asking for a name.
class UpdateMeUseCase(
  final ProfileRepository _profile,
  final AuthRepository _auth,
) implements UseCase<ProfileData, UpdateMeParams> {
  @override
  Future<Either<Failure, ProfileData>> call(UpdateMeParams params) async {
    final name = params.name?.trim();
    final phone = params.phone?.trim();
    final result = await _profile.updateMe(
      name: name,
      phone: phone == null || phone.isEmpty ? null : phone,
    );
    if (result case Right(value: final user)) {
      // The server has the change; a failed cache write only means the next
      // launch asks for the name again.
      await _auth.saveCurrentUser(user);
    }
    return result;
  }
}

@riverpod
UpdateMeUseCase updateMeUseCase(Ref ref) => UpdateMeUseCase(
  ref.watch(profileRepositoryProvider),
  ref.watch(authRepositoryProvider),
);
