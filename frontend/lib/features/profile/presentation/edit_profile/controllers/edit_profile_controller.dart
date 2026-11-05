import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../auth/presentation/shared/controllers/auth_session_controller.dart';
import '../../../domain/usecases/update_me_usecase.dart';

part 'edit_profile_controller.g.dart';

/// Saves Edit profile. Loading and the last failure live in the
/// `AsyncValue`; the page decides which fields changed.
@riverpod
class EditProfileController() extends _$EditProfileController {
  @override
  FutureOr<void> build() {}

  /// Sends the changed [name] and [phone] (E.164); [clearPhone] removes the
  /// number. Returns true when it was saved.
  Future<bool> save({String? name, String? phone, bool clearPhone = false}) async {
    if (state.isLoading) return false;

    state = const AsyncLoading();
    final result = await ref.read(updateMeUseCaseProvider)((
      name: name,
      phone: phone,
      clearPhone: clearPhone,
    ));
    if (!ref.mounted) return result.isRight();

    switch (result) {
      case Left(:final value):
        state = AsyncError(value, StackTrace.current);
      case Right():
        state = const AsyncData(null);
        // Re-read the cached user so the Profil tab shows the change.
        await ref.read(authSessionControllerProvider.notifier).refresh(unlocked: true);
    }
    return result.isRight();
  }

  /// Drops a shown server error once the user edits again.
  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }
}
