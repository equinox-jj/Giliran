import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/history/data/repositories/history_repository_impl.dart';
import 'package:giliran/features/history/domain/entities/activity_description.dart';
import 'package:giliran/features/history/domain/entities/activity_entry.dart';
import 'package:giliran/features/history/presentation/activity_tab/controllers/activity_tab_controller.dart';

import '../../../../../helpers/fake_history_repository.dart';

ActivityEntry _entry(String id) =>
    ActivityEntry(id: id, action: 'payment.approved', createdAt: DateTime.utc(2026, 11, 3));

void main() {
  late FakeHistoryRepository repository;
  late ProviderContainer container;
  final provider = activityTabControllerProvider('g1');

  setUp(() {
    repository = FakeHistoryRepository();
    container = ProviderContainer(overrides: [historyRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
  });

  Future<ActivityTabState> settle() async {
    await pumpEventQueue();
    return container.read(provider).requireValue;
  }

  test('build refreshes the newest page and describes each entry', () async {
    // Arrange
    repository
      ..first = [_entry('2'), _entry('1')]
      ..firstCursor = const ActivityCursor(nextCursor: 'c1', hasMore: true);
    container.listen(provider, (_, _) {});

    // Act
    final state = await settle();

    // Assert
    expect(repository.refreshCount, 1);
    expect(state.loaded, isTrue);
    expect(state.hasMore, isTrue);
    expect(state.entries.map((e) => e.entry.id), ['2', '1']);
    expect(state.entries.first.description.kind, ActivityKind.paymentApproved);
  });

  test('loadMore requests next_cursor once per page', () async {
    // Arrange
    repository
      ..first = [_entry('3')]
      ..firstCursor = const ActivityCursor(nextCursor: 'c1', hasMore: true)
      ..pages['c1'] = ([_entry('2')], const ActivityCursor(nextCursor: 'c2', hasMore: true))
      ..pages['c2'] = ([_entry('1')], const ActivityCursor());
    container.listen(provider, (_, _) {});
    await settle();
    final notifier = container.read(provider.notifier);

    // Act
    await Future.wait([notifier.loadMore(), notifier.loadMore()]);
    await notifier.loadMore();
    await notifier.loadMore();
    final state = await settle();

    // Assert
    expect(repository.loadedCursors, ['c1', 'c2']);
    expect(state.hasMore, isFalse);
    expect(state.entries.map((e) => e.entry.id), ['3', '2', '1']);
  });

  test('a failed page is not retried until retryMore', () async {
    // Arrange
    repository
      ..firstCursor = const ActivityCursor(nextCursor: 'c1', hasMore: true)
      ..loadMoreFailure = const Failure.network()
      ..pages['c1'] = ([_entry('1')], const ActivityCursor());
    container.listen(provider, (_, _) {});
    await settle();
    final notifier = container.read(provider.notifier);
    await notifier.loadMore();
    await notifier.loadMore();
    expect(repository.loadedCursors, ['c1']);
    expect((await settle()).failure, isNotNull);
    repository.loadMoreFailure = null;

    // Act
    await notifier.retryMore();
    final state = await settle();

    // Assert
    expect(repository.loadedCursors, ['c1', 'c1']);
    expect(state.failure, isNull);
    expect(state.hasMore, isFalse);
  });

  test('refresh starts paging over', () async {
    // Arrange
    repository
      ..firstCursor = const ActivityCursor(nextCursor: 'c1', hasMore: true)
      ..pages['c1'] = ([_entry('1')], const ActivityCursor(nextCursor: 'c2', hasMore: true));
    container.listen(provider, (_, _) {});
    await settle();
    final notifier = container.read(provider.notifier);
    await notifier.loadMore();

    // Act
    await notifier.refresh();
    await notifier.loadMore();

    // Assert
    expect(repository.loadedCursors, ['c1', 'c1']);
  });
}
