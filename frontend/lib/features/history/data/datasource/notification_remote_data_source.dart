/// The push-token endpoint.
abstract interface class NotificationRemoteDataSource() {
  /// Saves [token] on the current session (`PUT /me/push-token`).
  Future<void> putPushToken(String token);
}
