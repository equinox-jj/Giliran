import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/member_input.dart';
import '../../../domain/usecases/add_guest_usecase.dart';
import '../../../domain/usecases/update_guest_usecase.dart';

part 'guest_controller.freezed.dart';
part 'guest_controller.g.dart';

/// The guest sheet while it saves, and its last failure.
@freezed
abstract class GuestState with _$GuestState {
  const factory({@Default(false) bool saving, Failure? failure}) = _GuestState;
}

/// Adds or edits a guest for the guest sheet.
@riverpod
class GuestController() extends _$GuestController {
  @override
  GuestState build(String groupId) => const GuestState();

  /// Adds a guest. Returns the new member, or null on failure.
  Future<Member?> add(GuestInput input) =>
      _run(() => ref.read(addGuestUseCaseProvider)((groupId: groupId, input: input)));

  /// Edits guest [memberId]. Returns the member, or null on failure.
  Future<Member?> update(String memberId, UpdateGuestInput input) =>
      _run(() => ref.read(updateGuestUseCaseProvider)((groupId: groupId, memberId: memberId, input: input)));

  Future<Member?> _run(Future<Either<Failure, Member>> Function() call) async {
    if (state.saving) return null;
    state = const GuestState(saving: true);
    final result = await call();
    if (ref.mounted) state = GuestState(failure: result.getLeft().toNullable());
    return result.toNullable();
  }
}
