/// How often a group collects (`groups.period_type`).
enum PeriodType(final String apiValue) {
  weekly('weekly'),
  monthly('monthly');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static PeriodType? fromApi(String? value) => PeriodType.values.where((e) => e.apiValue == value).firstOrNull;
}
