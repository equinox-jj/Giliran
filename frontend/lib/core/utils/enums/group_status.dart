/// A group's lifecycle state (`groups.status`, DB_SCHEME §4).
enum GroupStatus(final String apiValue) {
  draft('draft'),
  active('active'),
  completed('completed'),
  closed('closed');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static GroupStatus? fromApi(String? value) => GroupStatus.values.where((e) => e.apiValue == value).firstOrNull;
}
