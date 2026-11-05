/// Why a push reminder was not sent to a member (`ReminderResult.skipped`).
/// The organizer can still reach them on WhatsApp.
enum ReminderSkipReason(final String apiValue) {
  guest('guest'),
  noDevice('no_device'),
  notificationsOff('notifications_off'),
  recentlyReminded('recently_reminded'),
  alreadyPaid('already_paid');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static ReminderSkipReason? fromApi(String? value) =>
      ReminderSkipReason.values.where((e) => e.apiValue == value).firstOrNull;
}
