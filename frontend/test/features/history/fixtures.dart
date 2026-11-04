/// An `ActivityEntry` as the API sends it (api-spec `ActivityEntry`).
Map<String, dynamic> activityJson(
  String id, {
  String action = 'payment.approved',
  String entityType = 'payment',
  DateTime? createdAt,
  Map<String, dynamic>? actor = const {'id': 'u1', 'name': 'Bu Rina', 'avatar_url': null},
  Map<String, dynamic>? subject = const {
    'id': 'm2',
    'display_name': 'Pak Dedi',
    'avatar_url': null,
    'is_guest': false,
    'slot_no': 2,
  },
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
}) => {
  'id': id,
  'action': action,
  'entity_type': entityType,
  'entity_id': '0b9e6a52-6c1e-4d0b-9e4e-3c2f1a7d8e90',
  'actor': actor,
  'subject': subject,
  'before': before,
  'after': after,
  'created_at': (createdAt ?? DateTime.utc(2026, 11, 3, 12)).toIso8601String(),
};
