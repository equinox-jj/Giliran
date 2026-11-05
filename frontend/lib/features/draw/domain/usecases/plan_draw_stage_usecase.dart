import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/member_status.dart';
import '../../../../core/utils/enums/period_status.dart';
import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';
import '../../../payment/domain/entities/period.dart';

part 'plan_draw_stage_usecase.freezed.dart';
part 'plan_draw_stage_usecase.g.dart';

/// Why the Kocok button is not available right now.
enum DrawBlocker() {
  /// Members watch; only organizers and co-organizers draw.
  notManager,

  /// The period is not open (upcoming, or already drawn).
  notOpen,

  /// Before `draw_date`.
  tooEarly,

  /// Draws need a connection.
  offline,
}

typedef DrawStageInput = ({GroupDetail group, Period period, List<Member> members, bool online, DateTime now});

/// What the draw stage shows: who takes part, the next person for
/// fixed order, and whether the viewer can run the draw.
@freezed
abstract class const DrawStagePlan._() with _$DrawStagePlan {
  const factory({
    /// Slots that have not won yet, by slot number.
    required List<Member> eligible,
    required bool fixedOrder,

    /// Fixed order only: the lowest unwon position.
    Member? nextInOrder,
    required bool manager,
    DrawBlocker? blocker,

    /// The draw date, for "Bisa dikocok {date}".
    DateTime? availableOn,
  }) = _DrawStagePlan;

  bool get canRun => blocker == null;
}

/// Builds the [DrawStagePlan] from the cached group, period and members.
/// The server enforces every rule again; this only decides what to show.
class const PlanDrawStageUseCase() {
  DrawStagePlan call(DrawStageInput input) {
    final (:group, :period, :members, :online, :now) = input;
    final eligible = [
      for (final m in members)
        if (m.hasWon != true && m.status != MemberStatus.left && m.status != MemberStatus.removed) m,
    ]..sort((a, b) => (a.slotNo ?? 0).compareTo(b.slotNo ?? 0));
    final fixedOrder = group.drawMethod == DrawMethod.fixedOrder;
    final byPosition = [...eligible]
      ..sort((a, b) => (a.fixedOrderPosition ?? 1 << 30).compareTo(b.fixedOrderPosition ?? 1 << 30));
    final drawDate = period.drawDate;
    final tooEarly = drawDate != null && AppDate.jakartaToday(now).isBefore(drawDate);
    final blocker = switch (null) {
      _ when !group.isManager => DrawBlocker.notManager,
      _ when period.status != PeriodStatus.open => DrawBlocker.notOpen,
      _ when tooEarly => DrawBlocker.tooEarly,
      _ when !online => DrawBlocker.offline,
      _ => null,
    };
    return DrawStagePlan(
      eligible: eligible,
      fixedOrder: fixedOrder,
      nextInOrder: fixedOrder ? byPosition.firstOrNull : null,
      manager: group.isManager,
      blocker: blocker,
      availableOn: drawDate,
    );
  }
}

@Riverpod(keepAlive: true)
PlanDrawStageUseCase planDrawStageUseCase(Ref ref) => const PlanDrawStageUseCase();
