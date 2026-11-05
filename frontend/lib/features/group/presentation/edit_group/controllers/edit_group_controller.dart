import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/group_input.dart';
import '../../../domain/usecases/close_group_usecase.dart';
import '../../../domain/usecases/update_group_usecase.dart';

part 'edit_group_controller.g.dart';

/// Saves Edit group one setting at a time and closes the group. The
/// group itself is read from the detail controller's cache stream, which
/// picks up each saved change.
@riverpod
class EditGroupController() extends _$EditGroupController {
  @override
  bool build(String groupId) => false;

  /// Sends [input]. Returns the failure, if any.
  Future<Failure?> save(UpdateGroupInput input) async {
    if (state) return null;
    state = true;
    final result = await ref.read(updateGroupUseCaseProvider)((groupId: groupId, input: input));
    if (ref.mounted) state = false;
    return result.getLeft().toNullable();
  }

  /// Closes the group for good. Returns the failure, if any.
  Future<Failure?> close() async {
    if (state) return null;
    state = true;
    final result = await ref.read(closeGroupUseCaseProvider)(groupId);
    if (ref.mounted) state = false;
    return result.getLeft().toNullable();
  }
}
