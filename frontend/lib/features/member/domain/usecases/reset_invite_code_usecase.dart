import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../group/domain/entities/group.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'reset_invite_code_usecase.g.dart';

/// Replaces the invite code; old links stop working.
class const ResetInviteCodeUseCase(final MemberRepository _repository) implements UseCase<Invite, String> {
  @override
  Future<Either<Failure, Invite>> call(String params) => _repository.resetInviteCode(params);
}

@Riverpod(keepAlive: true)
ResetInviteCodeUseCase resetInviteCodeUseCase(Ref ref) => ResetInviteCodeUseCase(ref.watch(memberRepositoryProvider));
