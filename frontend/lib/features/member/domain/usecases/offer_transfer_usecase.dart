import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/ownership_transfer.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'offer_transfer_usecase.g.dart';

/// Offers the organizer role to a member with an account.
class const OfferTransferUseCase(final MemberRepository _repository)
    implements UseCase<OwnershipTransfer, ({String groupId, String toMemberId})> {
  @override
  Future<Either<Failure, OwnershipTransfer>> call(({String groupId, String toMemberId}) params) =>
      _repository.offerTransfer(params.groupId, params.toMemberId);
}

@Riverpod(keepAlive: true)
OfferTransferUseCase offerTransferUseCase(Ref ref) => OfferTransferUseCase(ref.watch(memberRepositoryProvider));
