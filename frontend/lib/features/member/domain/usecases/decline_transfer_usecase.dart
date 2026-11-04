import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/ownership_transfer.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'decline_transfer_usecase.g.dart';

/// Declines the organizer role (S33).
class const DeclineTransferUseCase(final MemberRepository _repository)
    implements UseCase<OwnershipTransfer, ({String groupId, String transferId})> {
  @override
  Future<Either<Failure, OwnershipTransfer>> call(({String groupId, String transferId}) params) =>
      _repository.declineTransfer(params.groupId, params.transferId);
}

@Riverpod(keepAlive: true)
DeclineTransferUseCase declineTransferUseCase(Ref ref) => DeclineTransferUseCase(ref.watch(memberRepositoryProvider));
