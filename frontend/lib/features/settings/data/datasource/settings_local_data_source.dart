/// Device-only data behind Settings (S47). Throws `CacheException` on
/// failure.
abstract interface class SettingsLocalDataSource() {
  /// Empties the downloaded image cache (avatars, proofs, QRIS) and the
  /// in-memory decoded images.
  Future<void> clearImageCache();
}
