import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/ownership_transfer.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'accept_transfer_usecase.g.dart';

/// Accepts the organizer role.
class const AcceptTransferUseCase(final MemberRepository _repository)
    implements UseCase<OwnershipTransfer, ({String groupId, String transferId})> {
  @override
  Future<Either<Failure, OwnershipTransfer>> call(({String groupId, String transferId}) params) =>
      _repository.acceptTransfer(params.groupId, params.transferId);
}

@Riverpod(keepAlive: true)
AcceptTransferUseCase acceptTransferUseCase(Ref ref) => AcceptTransferUseCase(ref.watch(memberRepositoryProvider));
