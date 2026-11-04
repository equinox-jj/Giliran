/// A member's state in a group (`group_members.status`).
enum MemberStatus(final String apiValue) {
  active('active'),
  left('left'),
  removed('removed');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static MemberStatus? fromApi(String? value) => MemberStatus.values.where((e) => e.apiValue == value).firstOrNull;
}
