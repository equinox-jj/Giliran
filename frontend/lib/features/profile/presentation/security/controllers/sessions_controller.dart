import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entity/session.dart';
import '../../../domain/usecases/get_sessions_usecase.dart';
import '../../../domain/usecases/revoke_other_sessions_usecase.dart';
import '../../../domain/usecases/revoke_session_usecase.dart';

part 'sessions_controller.g.dart';

/// The "Perangkat aktif" list on Security.
@riverpod
class SessionsController() extends _$SessionsController {
  @override
  Future<List<Session>> build() => _load();

  /// Loads the list again, such as from the error state's "Coba lagi".
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Signs out the session [id]. Returns the failure when the server kept
  /// it; the row stays in that case.
  Future<Failure?> revoke(String id) async {
    final result = await ref.read(revokeSessionUseCaseProvider)(id);
    if (!ref.mounted) return result.getLeft().toNullable();
    if (result.isRight()) {
      if (state.value case final sessions?) {
        state = AsyncData([
          for (final s in sessions)
            if (s.id != id) s,
        ]);
      }
    }
    return result.getLeft().toNullable();
  }

  /// Signs out every other device; returns how many were signed out.
  Future<Either<Failure, int>> revokeOthers() async {
    final sessions = state.value ?? const <Session>[];
    final result = await ref.read(revokeOtherSessionsUseCaseProvider)(sessions);
    if (!ref.mounted) return result;
    switch (result) {
      case Right():
        state = AsyncData([
          for (final s in sessions)
            if (s.isCurrent == true) s,
        ]);
      case Left():
        // Some may be gone already; show what the server has now.
        state = await AsyncValue.guard(_load);
    }
    return result;
  }

  Future<List<Session>> _load() async {
    final result = await ref.read(getSessionsUseCaseProvider)(const NoParams());
    return result.fold((failure) => throw failure, (sessions) => sessions);
  }
}
