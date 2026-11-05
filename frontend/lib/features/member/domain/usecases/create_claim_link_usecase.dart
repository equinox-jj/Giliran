import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/claim_link.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'create_claim_link_usecase.g.dart';

/// A 7-day link that lets a guest take over their slot.
class const CreateClaimLinkUseCase(final MemberRepository _repository)
    implements UseCase<ClaimLink, ({String groupId, String memberId})> {
  @override
  Future<Either<Failure, ClaimLink>> call(({String groupId, String memberId}) params) =>
      _repository.createClaimLink(params.groupId, params.memberId);
}

@Riverpod(keepAlive: true)
CreateClaimLinkUseCase createClaimLinkUseCase(Ref ref) => CreateClaimLinkUseCase(ref.watch(memberRepositoryProvider));
