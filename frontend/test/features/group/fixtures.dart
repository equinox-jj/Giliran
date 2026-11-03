/// API bodies copied from the `Group` and `GroupSummary` schemas in
/// `backend/api/api-spec.yaml`.
const groupJson = <String, dynamic>{
  'id': '0190a1b2-0000-7000-8000-000000000001',
  'name': 'Arisan RT 05',
  'amount': 200000,
  'pot_amount': 2000000,
  'period_type': 'monthly',
  'total_slots': 10,
  'filled_slots': 8,
  'draw_method': 'random',
  'start_date': '2026-11-25',
  'reminder_days_before': 2,
  'status': 'draft',
  'organizer': {'id': 'u-1', 'name': 'Rina Ayu', 'avatar_url': null},
  'my_role': 'organizer',
  'my_member_id': 'm-1',
  'invite': {
    'invite_code': 'K7P2QX9M',
    'invite_url': 'https://giliran.monai.my.id/j/K7P2QX9M',
  },
  'payment_info': {
    'bank_name': 'BCA',
    'account_number': '1234567890',
    'account_holder': 'Rina Ayu',
    'qris_image_url': 'https://cdn.test/qris.png?sig=1',
    'qris_merchant_name': 'RINA AYU',
  },
  'current_period_id': null,
  'started_at': null,
  'completed_at': null,
  'closed_at': null,
  'created_at': '2026-11-01T03:00:00Z',
  'updated_at': '2026-11-01T03:00:00Z',
};

Map<String, dynamic> summaryJson(
  String id, {
  String name = 'Arisan RT 05',
  String status = 'active',
  String? nextDueDate = '2026-11-25',
}) => {
  'id': id,
  'name': name,
  'amount': 200000,
  'period_type': 'monthly',
  'status': status,
  'my_role': 'member',
  'total_slots': 10,
  'filled_slots': 10,
  'current_period_no': 3,
  'next_due_date': nextDueDate,
  'next_draw_date': nextDueDate,
  'my_payment_status': 'unpaid',
  'paid_count': 4,
  'pending_review_count': null,
  'i_have_won': false,
};
