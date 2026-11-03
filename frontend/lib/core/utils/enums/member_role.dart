/// A member's role in a group (`members.role`).
enum MemberRole(final String apiValue) {
  organizer('organizer'),
  coOrganizer('co_organizer'),
  member('member');

  /// Returns the role for an API [value], or `null` when it is missing or
  /// unknown.
  static MemberRole? fromApi(String? value) => MemberRole.values.where((e) => e.apiValue == value).firstOrNull;
}
