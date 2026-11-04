import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/activity_description.dart';
import '../../../domain/entities/activity_entry.dart';
import '../../../domain/usecases/describe_activity_usecase.dart';
import '../../../domain/usecases/load_more_activity_usecase.dart';
import '../../../domain/usecases/refresh_activity_usecase.dart';
import '../../../domain/usecases/watch_activity_usecase.dart';

part 'activity_tab_controller.freezed.dart';
part 'activity_tab_controller.g.dart';

/// An entry with what its row says.
typedef ActivityItem = ({ActivityEntry entry, ActivityDescription description});

/// The Aktivitas tab (S23): the cached entries and where the next page
/// starts.
@freezed
abstract class ActivityTabState with _$ActivityTabState {
  const factory({
    /// Newest first.
    @Default(<ActivityItem>[]) List<ActivityItem> entries,

    /// Older entries exist on the server; true until the first page says
    /// otherwise.
    @Default(true) bool hasMore,

    /// Where the next page starts; null until the first refresh brings it.
    String? nextCursor,
    @Default(false) bool loadingMore,

    /// The first refresh finished (or failed).
    @Default(false) bool loaded,

    /// The last refresh or page load failed and nothing newer replaced it.
    Failure? failure,
  }) = _ActivityTabState;
}

/// Watches a group's cached activity log, refreshes the newest page on
/// open and on pull-to-refresh, and loads older pages as the list nears
/// its end, requesting each `next_cursor` once.
@riverpod
class ActivityTabController() extends _$ActivityTabController {
  var _entries = const <ActivityItem>[];
  String? _cursor;
  var _hasMore = true;
  var _loadingMore = false;
  var _loaded = false;
  Failure? _failure;

  /// The cursors already asked for, so a list that rebuilds near its end
  /// doesn't fetch the same page twice.
  final _requested = <String>{};

  @override
  Stream<ActivityTabState> build(String groupId) {
    unawaited(Future.microtask(refresh));
    return ref.watch(watchActivityUseCaseProvider)(groupId).map((result) {
      if (result case Right(:final value)) {
        final describe = ref.read(describeActivityUseCaseProvider);
        _entries = [for (final e in value) (entry: e, description: describe(e))];
      }
      return _compose();
    });
  }

  /// Fetches the newest page into the cache, starting paging over.
  /// Returns the failure, if any.
  Future<Failure?> refresh() async {
    final result = await ref.read(refreshActivityUseCaseProvider)(groupId);
    if (!ref.mounted) return result.getLeft().toNullable();
    _loaded = true;
    switch (result) {
      case Left(:final value):
        _failure = value;
      case Right(:final value):
        _failure = null;
        _requested.clear();
        _cursor = value.nextCursor;
        _hasMore = value.hasMore && value.nextCursor != null;
    }
    _emit();
    return _failure;
  }

  /// Loads the next older page, unless one is loading, none is left or
  /// this cursor was already requested.
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_loadingMore || !_hasMore || cursor == null || !_requested.add(cursor)) return;
    _loadingMore = true;
    _emit();
    final result = await ref.read(loadMoreActivityUseCaseProvider)((groupId: groupId, cursor: cursor));
    if (!ref.mounted) return;
    _loadingMore = false;
    switch (result) {
      case Left(:final value):
        // The cursor stays requested so the end row doesn't retry on every
        // rebuild; [retryMore] asks again.
        _failure = value;
      case Right(:final value):
        _failure = null;
        _cursor = value.nextCursor;
        _hasMore = value.hasMore && value.nextCursor != null;
    }
    _emit();
  }

  /// Asks again for the page whose load failed ("Coba lagi").
  Future<void> retryMore() async {
    final cursor = _cursor;
    if (cursor != null) _requested.remove(cursor);
    await loadMore();
  }

  ActivityTabState _compose() => ActivityTabState(
    entries: _entries,
    hasMore: _hasMore,
    nextCursor: _cursor,
    loadingMore: _loadingMore,
    loaded: _loaded,
    failure: _failure,
  );

  void _emit() {
    if (ref.mounted && state.hasValue) state = AsyncData(_compose());
  }
}
