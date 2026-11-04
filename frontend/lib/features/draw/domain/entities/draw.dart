import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/draw_algorithm.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/draw_status.dart';
import '../../../group/domain/entities/group.dart';

part 'draw.freezed.dart';

/// One slot taking part in a draw, as listed on the stage and the verify
/// sheet.
@freezed
abstract class DrawSlot with _$DrawSlot {
  const factory({String? slotId, int? slotNo, String? displayName}) = _DrawSlot;
}

/// A period's draw (S37–S39): the published commitment before it runs, and
/// the revealed seed, eligible slots and winner after.
@freezed
abstract class const Draw._() with _$Draw {
  const factory({
    String? periodId,
    int? periodNo,
    DrawMethod? method,
    DrawAlgorithm? algorithm,
    DrawStatus? status,
    String? seedHash,
    String? seed,

    /// Slots that had not won yet, sorted by slot number. Empty before the
    /// draw.
    List<DrawSlot>? eligibleSlots,
    DrawSlot? winner,
    int? paidCountAtDraw,
    int? totalCountAtDraw,
    DateTime? drawnAt,
    UserSummary? drawnBy,
    String? verificationCode,
    String? verifyUrl,
  }) = _Draw;

  bool get isDrawn => status == DrawStatus.drawn;

  bool get isFixedOrder => method == DrawMethod.fixedOrder || algorithm == DrawAlgorithm.fixedOrderV1;
}

/// The device's own check of a draw (S39): the seed matches the published
/// hash, and recomputing the algorithm picks the same winner.
@freezed
abstract class const DrawVerification._() with _$DrawVerification {
  const factory({required bool hashMatches, required bool winnerMatches}) = _DrawVerification;

  bool get matches => hashMatches && winnerMatches;
}
