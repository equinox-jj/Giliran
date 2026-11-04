import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/usecases/reset_invite_code_usecase.dart';

part 'invite_controller.g.dart';

/// Invite (S16) actions: whether a new invite code is being made. The
/// group (with its invite) and the members come from their own controllers.
@riverpod
class InviteController() extends _$InviteController {
  @override
  bool build(String groupId) => false;

  /// Replaces the invite code; the cached group picks up the new link.
  /// Returns the failure, if any.
  Future<Failure?> resetCode() async {
    if (state) return null;
    state = true;
    final result = await ref.read(resetInviteCodeUseCaseProvider)(groupId);
    if (ref.mounted) state = false;
    return result.getLeft().toNullable();
  }
}
