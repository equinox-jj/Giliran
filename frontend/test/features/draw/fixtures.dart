/// API JSON and entities for the draw feature tests, shaped like
/// `api-spec.yaml`. The drawn values are golden vector 0 from
/// `backend/internal/draw/testdata/golden.json`, so they verify.
library;

import 'package:giliran/core/utils/enums/draw_algorithm.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/draw_status.dart';
import 'package:giliran/features/draw/domain/entities/draw.dart';
import 'package:giliran/features/group/domain/entities/group.dart';

const goldenSeed = '0000000000000000000000000000000000000000000000000000000000000000';
const goldenSeedHash = '66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925';
const goldenPeriodId = '01890a5d-ac96-774b-bcce-b302099a8057';

String goldenSlotId(int n) => '01930000-0000-0000-0000-${n.toRadixString(16).padLeft(12, '0')}';

const _names = ['Bu Rina', 'Pak Budi', 'Sari', 'Dewi', 'Agus', 'Wati', 'Joko', 'Lina', 'Tono', 'Maya'];

Map<String, Object?> drawSlotJson(int n) => {'slot_id': goldenSlotId(n), 'slot_no': n, 'display_name': _names[n - 1]};

Map<String, Object?> committedDrawJson({String method = 'random'}) => {
  'period_id': goldenPeriodId,
  'period_no': 4,
  'method': method,
  'algorithm': method == 'random' ? 'hmac-sha256-v1' : 'fixed-order-v1',
  'status': 'committed',
  'seed_hash': method == 'random' ? goldenSeedHash : null,
  'seed': null,
  'eligible_slots': <Object?>[],
  'winner': null,
  'drawn_at': null,
  'drawn_by': null,
  'verification_code': null,
  'verify_url': null,
};

Map<String, Object?> drawnDrawJson() => {
  ...committedDrawJson(),
  'status': 'drawn',
  'seed': goldenSeed,
  'eligible_slots': [for (var n = 1; n <= 10; n++) drawSlotJson(n)],
  'winner': drawSlotJson(5),
  'paid_count_at_draw': 8,
  'total_count_at_draw': 10,
  'drawn_at': '2026-10-26T12:30:00Z',
  'drawn_by': {'id': 'u1', 'name': 'Pak Budi', 'avatar_url': null},
  'verification_code': '7H2K9QX4MP',
  'verify_url': 'https://giliran.monai.my.id/v/7H2K9QX4MP',
};

DrawSlot drawSlot(int n) => DrawSlot(slotId: goldenSlotId(n), slotNo: n, displayName: _names[n - 1]);

const committedDraw = Draw(
  periodId: goldenPeriodId,
  periodNo: 4,
  method: DrawMethod.random,
  algorithm: DrawAlgorithm.hmacSha256V1,
  status: DrawStatus.committed,
  seedHash: goldenSeedHash,
  eligibleSlots: [],
);

final drawnDraw = committedDraw.copyWith(
  status: DrawStatus.drawn,
  seed: goldenSeed,
  eligibleSlots: [for (var n = 1; n <= 10; n++) drawSlot(n)],
  winner: drawSlot(5),
  paidCountAtDraw: 8,
  totalCountAtDraw: 10,
  drawnAt: DateTime.utc(2026, 10, 26, 12, 30),
  drawnBy: const UserSummary(id: 'u1', name: 'Pak Budi'),
  verificationCode: '7H2K9QX4MP',
  verifyUrl: 'https://giliran.monai.my.id/v/7H2K9QX4MP',
);
