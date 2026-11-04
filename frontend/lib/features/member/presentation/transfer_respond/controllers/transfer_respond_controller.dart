import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/ownership_transfer.dart';
import '../../../domain/usecases/accept_transfer_usecase.dart';
import '../../../domain/usecases/decline_transfer_usecase.dart';

part 'transfer_respond_controller.g.dart';

/// Transfer ownership respond (S33): whether an answer is being sent.
@riverpod
class TransferRespondController() extends _$TransferRespondController {
  @override
  bool build(String groupId, String transferId) => false;

  /// Accepts the organizer role. Returns the failure, if any.
  Future<Failure?> accept() =>
      _answer(() => ref.read(acceptTransferUseCaseProvider)((groupId: groupId, transferId: transferId)));

  /// Declines the organizer role. Returns the failure, if any.
  Future<Failure?> decline() =>
      _answer(() => ref.read(declineTransferUseCaseProvider)((groupId: groupId, transferId: transferId)));

  Future<Failure?> _answer(Future<Either<Failure, OwnershipTransfer>> Function() call) async {
    if (state) return null;
    state = true;
    final result = await call();
    if (ref.mounted) state = false;
    return result.getLeft().toNullable();
  }
}
