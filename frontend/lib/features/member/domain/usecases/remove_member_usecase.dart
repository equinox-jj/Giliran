import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'remove_member_usecase.g.dart';

/// Removes a member; the server refuses past winners with dues (`obligations_outstanding`).
class const RemoveMemberUseCase(final MemberRepository _repository)
    implements UseCase<Unit, ({String groupId, String memberId})> {
  @override
  Future<Either<Failure, Unit>> call(({String groupId, String memberId}) params) =>
      _repository.removeMember(params.groupId, params.memberId);
}

@Riverpod(keepAlive: true)
RemoveMemberUseCase removeMemberUseCase(Ref ref) => RemoveMemberUseCase(ref.watch(memberRepositoryProvider));
