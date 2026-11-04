import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/api_response.dart';
import 'package:giliran/features/history/data/datasource/history_local_data_source_impl.dart';
import 'package:giliran/features/history/data/datasource/history_remote_data_source.dart';
import 'package:giliran/features/history/data/datasource/model/activity_entry_model.dart';
import 'package:giliran/features/history/data/repositories/history_repository_impl.dart';
import 'package:giliran/features/history/domain/entities/activity_entry.dart';

import '../../../../core/database/fixtures.dart';
import '../../fixtures.dart';

/// Answers each cursor with its queued page.
class _FakeRemote() implements HistoryRemoteDataSource {
  final pages = <String?, CursorPage<ActivityEntryModel>>{};
  final cursors = <String?>[];
  Object? error;

  @override
  Future<CursorPage<ActivityEntryModel>> getActivity(
    String groupId, {
    String? cursor,
    int limit = HistoryRemoteDataSource.pageSize,
  }) async {
    cursors.add(cursor);
    if (error case final e?) throw e;
    return pages[cursor]!;
  }
}

CursorPage<ActivityEntryModel> _page(List<String> ids, {String? next, int hour = 12}) => CursorPage(
  items: [
    for (var i = 0; i < ids.length; i++)
      ActivityEntryModel.fromJson(activityJson(ids[i], createdAt: DateTime.utc(2026, 11, 3, hour, 59 - i))),
  ],
  nextCursor: next,
  hasMore: next != null,
);

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late HistoryRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    remote = _FakeRemote();
    repository = HistoryRepositoryImpl(remote, HistoryLocalDataSourceImpl(db.activityLogsDao));
    await db.groupsDao.upsertAll([groupRow('g1')]);
  });
  tearDown(() => db.close());

  Future<List<String?>> cachedIds() async {
    final result = await repository.watchActivity('g1').first;
    return result.getOrElse((_) => const <ActivityEntry>[]).map((e) => e.id).toList();
  }

  test('refresh writes the newest page the watch stream then emits', () async {
    // Arrange
    remote.pages[null] = _page(['3', '2'], next: 'c1');

    // Act
    final result = await repository.refreshActivity('g1');

    // Assert
    expect(result.getOrElse((_) => const ActivityCursor()).nextCursor, 'c1');
    expect(await cachedIds(), ['3', '2']);
    final first = (await repository.watchActivity('g1').first).getOrElse((_) => const []).first;
    expect(first.actor?.name, 'Bu Rina');
    expect(first.subject?.displayName, 'Pak Dedi');
    expect(first.subject?.slotNo, 2);
  });

  test('refresh replaces older cached entries so no gap is left', () async {
    // Arrange
    await db.activityLogsDao.upsertAll('g1', [activityRow('old', 'g1', DateTime.utc(2026, 10, 1))]);
    remote.pages[null] = _page(['3', '2'], next: 'c1');

    // Act
    await repository.refreshActivity('g1');

    // Assert
    expect(await cachedIds(), ['3', '2']);
  });

  test('loadMore appends the page at the cursor', () async {
    // Arrange
    remote.pages[null] = _page(['3', '2'], next: 'c1');
    remote.pages['c1'] = _page(['1'], hour: 8);
    await repository.refreshActivity('g1');

    // Act
    final result = await repository.loadMoreActivity('g1', 'c1');

    // Assert
    expect(remote.cursors, [null, 'c1']);
    expect(result.getOrElse((_) => const ActivityCursor(hasMore: true)).hasMore, isFalse);
    expect(await cachedIds(), ['3', '2', '1']);
  });

  test('a server failure leaves the cache and comes back as a Failure', () async {
    // Arrange
    await db.activityLogsDao.upsertAll('g1', [activityRow('old', 'g1', DateTime.utc(2026, 10, 1))]);
    remote.error = const NetworkException();

    // Act
    final result = await repository.refreshActivity('g1');

    // Assert
    expect(result, isA<Left<Failure, ActivityCursor>>());
    expect(await cachedIds(), ['old']);
  });
}
