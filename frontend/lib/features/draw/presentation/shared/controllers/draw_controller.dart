import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/idempotency.dart';
import '../../../domain/entities/draw.dart';
import '../../../domain/usecases/get_draw_usecase.dart';
import '../../../domain/usecases/run_draw_usecase.dart';

part 'draw_controller.g.dart';

/// A period's draw from the API, shared by the stage and the result
///. [run] keeps one [IdempotencyKey] for the user's intent until the
/// draw succeeds, so a retry after a timeout and the resend after the
/// incomplete-payments confirmation are the same request to the server.
@riverpod
class DrawController() extends _$DrawController {
  IdempotencyKey? _key;

  @override
  Future<Draw> build(String groupId, String periodId) async {
    final result = await ref.read(getDrawUseCaseProvider)((groupId: groupId, periodId: periodId));
    return result.fold((failure) => throw failure, (draw) => draw);
  }

  /// Runs the draw. Returns the failure (for example `payments_incomplete`,
  /// `draw_already_done`), or null once the result is in [state].
  Future<Failure?> run({bool confirmIncomplete = false}) async {
    final key = _key ??= IdempotencyKey.generate();
    final result = await ref.read(runDrawUseCaseProvider)((
      groupId: groupId,
      periodId: periodId,
      confirmIncomplete: confirmIncomplete,
      key: key,
    ));
    switch (result) {
      case Left(:final value):
        return value;
      case Right(:final value):
        _key = null;
        if (ref.mounted) state = AsyncData(value);
        return null;
    }
  }
}
