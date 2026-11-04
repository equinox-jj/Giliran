import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../entities/member_input.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'add_guest_usecase.g.dart';

/// Adds a guest (no account) to the next free slot (S27). A name outside
/// [MemberRules] fails with a [ValidationFailure] before any request.
class const AddGuestUseCase(final MemberRepository _repository)
    implements UseCase<Member, ({String groupId, GuestInput input})> {
  @override
  Future<Either<Failure, Member>> call(({String groupId, GuestInput input}) params) async {
    final errors = MemberRules.checkGuestName(params.input.name);
    if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    return _repository.addGuest(params.groupId, params.input);
  }
}

@Riverpod(keepAlive: true)
AddGuestUseCase addGuestUseCase(Ref ref) => AddGuestUseCase(ref.watch(memberRepositoryProvider));
