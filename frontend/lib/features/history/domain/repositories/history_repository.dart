import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/activity_entry.dart';

/// A group's activity log, cached in Drift (the latest 200 entries) and
/// paged from the API with an opaque cursor.
abstract interface class HistoryRepository() {
  /// The cached entries of [groupId], newest first, live.
  Stream<Either<Failure, List<ActivityEntry>>> watchActivity(String groupId);

  /// Replaces the cache with the newest page (server wins) and says where
  /// the next one starts.
  Future<Either<Failure, ActivityCursor>> refreshActivity(String groupId);

  /// Adds the page at [cursor] to the cache.
  Future<Either<Failure, ActivityCursor>> loadMoreActivity(String groupId, String cursor);
}
