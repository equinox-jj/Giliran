/// API bodies copied from the member schemas in `backend/api/api-spec.yaml`.
Map<String, dynamic> memberJson(
  String id, {
  int slotNo = 1,
  String name = 'Rina Ayu',
  bool isGuest = false,
  String role = 'member',
  String? guestPhone,
  bool hasWon = false,
  int? wonPeriodNo,
  int? fixedOrderPosition,
}) => {
  'id': id,
  'user': isGuest ? null : {'id': 'u-$id', 'name': name, 'avatar_url': null},
  'display_name': name,
  'is_guest': isGuest,
  'guest_phone': guestPhone,
  'role': role,
  'status': 'active',
  'slot_id': 'slot-$slotNo',
  'slot_no': slotNo,
  'fixed_order_position': fixedOrderPosition,
  'has_won': hasWon,
  'won_period_no': wonPeriodNo,
  'joined_at': '2026-10-01T03:00:00Z',
};

Map<String, dynamic> memberRefJson(String id, {String name = 'Dedi', int slotNo = 3}) => {
  'id': id,
  'display_name': name,
  'avatar_url': null,
  'is_guest': false,
  'slot_no': slotNo,
};

const invitePreviewJson = <String, dynamic>{
  'group_id': '0190a1b2-0000-7000-8000-000000000001',
  'group_name': 'Arisan RT 05',
  'organizer': {'id': 'u-1', 'name': 'Rina Ayu', 'avatar_url': null},
  'amount': 200000,
  'period_type': 'monthly',
  'total_slots': 10,
  'filled_slots': 8,
  'start_date': '2026-11-25',
  'status': 'draft',
  'can_join': true,
  'already_member': false,
};

const claimLinkJson = <String, dynamic>{
  'claim_url': 'https://giliran.monai.my.id/c/3f9a1c00000000000000000000000000',
  'expires_at': '2026-11-11T03:00:00Z',
};

Map<String, dynamic> leaveRequestJson(String id, {String status = 'pending'}) => {
  'id': id,
  'member': memberRefJson('m-3'),
  'reason': 'Pindah kota',
  'status': status,
  'reviewed_by': null,
  'reviewed_at': null,
  'created_at': '2026-11-02T03:00:00Z',
};

Map<String, dynamic> transferJson(String id, {String status = 'pending'}) => {
  'id': id,
  'from_user': {'id': 'u-1', 'name': 'Rina Ayu', 'avatar_url': null},
  'to_member': memberRefJson('m-3'),
  'status': status,
  'expires_at': '2026-11-09T03:00:00Z',
  'responded_at': null,
  'created_at': '2026-11-02T03:00:00Z',
};

Map<String, dynamic> obligationJson(
  String memberId, {
  int wonPeriodNo = 3,
  int remainingCount = 7,
  int overdueCount = 0,
}) => {
  'member': memberRefJson(memberId),
  'won_period_no': wonPeriodNo,
  'remaining_count': remainingCount,
  'remaining_amount': remainingCount * 200000,
  'overdue_count': overdueCount,
  'overdue_amount': overdueCount * 200000,
};
