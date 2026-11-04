import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/history/domain/entities/activity_entry.dart';
import 'package:giliran/features/history/domain/repositories/history_repository.dart';

/// An in-memory activity log: [refreshActivity] answers [first], each
/// [loadMoreActivity] the page queued under its cursor, and both emit the
/// entries they "cached".
class FakeHistoryRepository() implements HistoryRepository {
  List<ActivityEntry> first = [];
  ActivityCursor firstCursor = const ActivityCursor();
  final pages = <String, (List<ActivityEntry>, ActivityCursor)>{};
  final loadedCursors = <String>[];
  Failure? refreshFailure;
  Failure? loadMoreFailure;
  int refreshCount = 0;

  /// Holds a load-more call until completed, to test overlapping calls.
  Completer<void>? loadGate;

  /// Holds the refresh until completed, like a slow network after the
  /// cache already showed.
  Completer<void>? refreshGate;

  var _cached = <ActivityEntry>[];

  /// Entries already cached before the first refresh.
  set cached(List<ActivityEntry> value) => _cached = value;
  final _watchers = <StreamController<List<ActivityEntry>>>[];

  /// Each watcher gets the cache on listen and every change after, like a
  /// Drift watch query.
  @override
  Stream<Either<Failure, List<ActivityEntry>>> watchActivity(String groupId) {
    late final StreamController<List<ActivityEntry>> watcher;
    watcher = StreamController(
      onListen: () {
        watcher.add(_cached);
        _watchers.add(watcher);
      },
      onCancel: () => _watchers.remove(watcher),
    );
    return watcher.stream.map(Right.new);
  }

  void _emit() {
    for (final w in [..._watchers]) {
      w.add(_cached);
    }
  }

  @override
  Future<Either<Failure, ActivityCursor>> refreshActivity(String groupId) async {
    refreshCount++;
    await refreshGate?.future;
    if (refreshFailure case final f?) return Left(f);
    _cached = [...first];
    _emit();
    return Right(firstCursor);
  }

  @override
  Future<Either<Failure, ActivityCursor>> loadMoreActivity(String groupId, String cursor) async {
    loadedCursors.add(cursor);
    await loadGate?.future;
    if (loadMoreFailure case final f?) return Left(f);
    final (entries, next) = pages[cursor]!;
    _cached = [..._cached, ...entries];
    _emit();
    return Right(next);
  }
}
