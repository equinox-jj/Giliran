import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../profile/domain/usecases/update_me_usecase.dart';
import '../../shared/controllers/auth_session_controller.dart';

part 'fill_name_controller.g.dart';

/// Saves the name on S05. The `Failure` surfaces as an `AsyncError`; field
/// errors (`min_length`, `max_length`) come with it.
@riverpod
class FillNameController() extends _$FillNameController {
  @override
  FutureOr<void> build() {}

  /// Saves [name] and the optional [phone] (E.164), then moves the session
  /// on to the PIN step. Returns true when it was saved.
  Future<bool> submit({required String name, String? phone}) async {
    if (state.isLoading) return false;

    state = const AsyncLoading();
    final result = await ref.read(updateMeUseCaseProvider)((name: name, phone: phone));
    if (!ref.mounted) return result.isRight();

    switch (result) {
      case Left(:final value):
        state = AsyncError(value, StackTrace.current);
      case Right():
        state = const AsyncData(null);
        // The user just verified the email code on this device.
        await ref.read(authSessionControllerProvider.notifier).refresh(unlocked: true);
    }
    return result.isRight();
  }
}
