import '../../../../core/utils/enums/draw_algorithm.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/draw_status.dart';
import '../../../group/domain/entities/group.dart';
import '../../domain/entities/draw.dart';
import '../datasource/model/draw_model.dart';

extension DrawSlotModelMapper on DrawSlotModel {
  DrawSlot toEntity() => DrawSlot(slotId: slotId, slotNo: slotNo, displayName: displayName);
}

extension DrawModelMapper on DrawModel {
  Draw toEntity() {
    final by = drawnBy;
    return Draw(
      periodId: periodId,
      periodNo: periodNo,
      method: DrawMethod.fromApi(method),
      algorithm: DrawAlgorithm.fromApi(algorithm),
      status: DrawStatus.fromApi(status),
      seedHash: seedHash,
      seed: seed,
      eligibleSlots: [for (final s in eligibleSlots ?? const <DrawSlotModel>[]) s.toEntity()],
      winner: winner?.toEntity(),
      paidCountAtDraw: paidCountAtDraw,
      totalCountAtDraw: totalCountAtDraw,
      drawnAt: drawnAt,
      drawnBy: by == null ? null : UserSummary(id: by.id, name: by.name, avatarUrl: by.avatarUrl),
      verificationCode: verificationCode,
      verifyUrl: verifyUrl,
    );
  }
}
