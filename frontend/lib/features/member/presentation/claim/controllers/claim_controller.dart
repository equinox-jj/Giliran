import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/usecases/claim_slot_usecase.dart';

part 'claim_controller.g.dart';

/// How a claim attempt ended: the group the slot is in (when known), or the
/// failure.
typedef ClaimOutcome = ({String? groupId, Failure? failure});

/// Claim guest slot (S29): whether the claim is running.
@riverpod
class ClaimController() extends _$ClaimController {
  @override
  bool build(String token) => false;

  Future<ClaimOutcome> claim() async {
    if (state) return (groupId: null, failure: null);
    state = true;
    final result = await ref.read(claimSlotUseCaseProvider)(token);
    if (ref.mounted) state = false;
    return switch (result) {
      Right(:final value) => (groupId: value, failure: null),
      Left(:final value) => (groupId: null, failure: value),
    };
  }
}
