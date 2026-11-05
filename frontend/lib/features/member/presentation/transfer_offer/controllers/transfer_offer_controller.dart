import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/ownership_transfer.dart';
import '../../../domain/usecases/offer_transfer_usecase.dart';

part 'transfer_offer_controller.freezed.dart';
part 'transfer_offer_controller.g.dart';

/// Transfer ownership offer: the chosen member and the offer sent in
/// this session. The API has no way to read a pending offer back, so after
/// leaving the screen a second offer answers `pending_request_exists`.
@freezed
abstract class TransferOfferState with _$TransferOfferState {
  const factory({String? selectedId, @Default(false) bool sending, OwnershipTransfer? offered}) = _TransferOfferState;
}

@riverpod
class TransferOfferController() extends _$TransferOfferController {
  @override
  TransferOfferState build(String groupId) => const TransferOfferState();

  void select(String memberId) => state = state.copyWith(selectedId: memberId);

  /// Offers the role to the selected member. Returns the failure, if any.
  Future<Failure?> offer() async {
    final target = state.selectedId;
    if (target == null || state.sending) return null;
    state = state.copyWith(sending: true);
    final result = await ref.read(offerTransferUseCaseProvider)((groupId: groupId, toMemberId: target));
    if (!ref.mounted) return result.getLeft().toNullable();
    state = switch (result) {
      Right(:final value) => state.copyWith(sending: false, offered: value),
      Left() => state.copyWith(sending: false),
    };
    return result.getLeft().toNullable();
  }
}
