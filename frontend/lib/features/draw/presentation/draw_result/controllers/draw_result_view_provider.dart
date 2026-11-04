import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../../member/presentation/shared/controllers/members_controller.dart';
import '../../../domain/usecases/describe_draw_result_usecase.dart';
import '../../shared/controllers/draw_controller.dart';

part 'draw_result_view_provider.g.dart';

/// The result screen's view of a finished draw; null until the draw has a
/// winner.
@riverpod
DrawResultView? drawResultView(Ref ref, String groupId, String periodId) {
  final draw = ref.watch(drawControllerProvider(groupId, periodId)).value;
  if (draw == null || draw.winner == null) return null;
  final detail = ref.watch(groupDetailControllerProvider(groupId)).value;
  final members = ref.watch(membersControllerProvider(groupId)).value ?? const [];
  return ref.watch(describeDrawResultUseCaseProvider)((
    draw: draw,
    group: detail?.group,
    period: detail?.periods.where((p) => p.id == periodId).firstOrNull,
    members: members,
  ));
}
