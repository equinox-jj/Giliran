import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'get_member_usecase.g.dart';

/// Fetches one member into the cache.
class const GetMemberUseCase(final MemberRepository _repository)
    implements UseCase<Member, ({String groupId, String memberId})> {
  @override
  Future<Either<Failure, Member>> call(({String groupId, String memberId}) params) =>
      _repository.getMember(params.groupId, params.memberId);
}

@Riverpod(keepAlive: true)
GetMemberUseCase getMemberUseCase(Ref ref) => GetMemberUseCase(ref.watch(memberRepositoryProvider));
