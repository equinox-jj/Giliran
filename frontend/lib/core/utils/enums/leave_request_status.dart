/// A leave request's state (`leave_requests.status`).
enum LeaveRequestStatus(final String apiValue) {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  cancelled('cancelled');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static LeaveRequestStatus? fromApi(String? value) =>
      LeaveRequestStatus.values.where((e) => e.apiValue == value).firstOrNull;
}
