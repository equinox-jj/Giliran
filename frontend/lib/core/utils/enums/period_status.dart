/// A period's lifecycle state (`periods.status`, DB_SCHEME §4).
enum PeriodStatus(final String apiValue) {
  upcoming('upcoming'),
  open('open'),
  drawn('drawn'),
  closed('closed');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static PeriodStatus? fromApi(String? value) => PeriodStatus.values.where((e) => e.apiValue == value).firstOrNull;
}
