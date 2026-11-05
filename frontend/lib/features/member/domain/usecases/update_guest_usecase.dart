import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../entities/member_input.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'update_guest_usecase.g.dart';

typedef UpdateGuestParams = ({String groupId, String memberId, UpdateGuestInput input});

/// Edits a guest's name or phone. A new name outside [MemberRules]
/// fails with a [ValidationFailure] before any request.
class const UpdateGuestUseCase(final MemberRepository _repository) implements UseCase<Member, UpdateGuestParams> {
  @override
  Future<Either<Failure, Member>> call(UpdateGuestParams params) async {
    if (params.input.name case final name?) {
      final errors = MemberRules.checkGuestName(name);
      if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    }
    return _repository.updateGuest(params.groupId, params.memberId, params.input);
  }
}

@Riverpod(keepAlive: true)
UpdateGuestUseCase updateGuestUseCase(Ref ref) => UpdateGuestUseCase(ref.watch(memberRepositoryProvider));
