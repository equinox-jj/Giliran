/// API JSON for the payment feature tests, shaped like `api-spec.yaml`.
library;

Map<String, Object?> memberRefJson(String id, {int slotNo = 1, String name = 'Rina Ayu', bool isGuest = false}) => {
  'id': id,
  'display_name': name,
  'avatar_url': null,
  'is_guest': isGuest,
  'slot_no': slotNo,
};

Map<String, Object?> paymentJson(
  String id, {
  String periodId = 'p1',
  String memberId = 'm1',
  int slotNo = 1,
  String name = 'Rina Ayu',
  String status = 'unpaid',
  String? method,
  bool isMine = false,
  bool isGuest = false,
  String? rejectReason,
  List<Map<String, Object?>>? proofs,
}) => {
  'id': id,
  'period_id': periodId,
  'member': memberRefJson(memberId, slotNo: slotNo, name: name, isGuest: isGuest),
  'amount': 200000,
  'status': status,
  'method': method,
  'current_proof': status == 'pending_review' ? proofJson('pr1') : null,
  'note': null,
  'reject_reason': rejectReason,
  'paid_at': status == 'paid' ? '2026-11-02T12:00:00Z' : null,
  'reviewed_by': null,
  'reviewed_at': null,
  'is_mine': isMine,
  'updated_at': '2026-11-02T12:00:00Z',
  'proofs': ?proofs,
};

Map<String, Object?> proofJson(String id) => {
  'id': id,
  'url': 'https://files.test/$id.jpg',
  'content_type': 'image/jpeg',
  'uploaded_at': '2026-11-02T12:02:00Z',
};

const summaryJson = <String, Object?>{
  'total_count': 10,
  'paid_count': 8,
  'pending_review_count': 1,
  'unpaid_count': 1,
  'rejected_count': 0,
  'collected_amount': 1600000,
  'expected_amount': 2000000,
};

Map<String, Object?> periodJson(
  String id, {
  int periodNo = 1,
  String status = 'open',
  Map<String, Object?>? winner,
  bool payoutRecorded = false,
}) => {
  'id': id,
  'period_no': periodNo,
  'due_date': '2026-11-25',
  'draw_date': '2026-11-25',
  'status': status,
  'seed_hash': null,
  'winner': winner,
  'drawn_at': null,
  'verification_code': null,
  'payment_summary': summaryJson,
  'payout_recorded': payoutRecorded,
  'payout_confirmed': false,
};

Map<String, Object?> payoutJson(String periodId) => {
  'id': 'po1',
  'period_id': periodId,
  'winner': memberRefJson('m1'),
  'amount': 2000000,
  'proof_url': null,
  'note': null,
  'recorded_by': {'id': 'u1', 'name': 'Bu Sari', 'avatar_url': null},
  'recorded_at': '2026-11-26T03:00:00Z',
  'confirmed_at': null,
};
