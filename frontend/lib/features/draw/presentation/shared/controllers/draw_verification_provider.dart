import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/entities/draw.dart';
import '../../../domain/usecases/verify_draw_usecase.dart';
import 'draw_controller.dart';

part 'draw_verification_provider.g.dart';

/// The device's own check of a finished draw (S39); null until the draw is
/// loaded and has run.
@riverpod
DrawVerification? drawVerification(Ref ref, String groupId, String periodId) {
  final draw = ref.watch(drawControllerProvider(groupId, periodId)).value;
  if (draw == null || !draw.isDrawn) return null;
  return ref.watch(verifyDrawUseCaseProvider)(draw);
}
