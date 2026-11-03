import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/group_list_filter.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/group/data/datasource/group_local_data_source_impl.dart';
import 'package:giliran/features/group/data/datasource/group_remote_data_source.dart';
import 'package:giliran/features/group/data/datasource/model/group_model.dart';
import 'package:giliran/features/group/data/datasource/model/group_request_model.dart';
import 'package:giliran/features/group/data/datasource/model/group_summary_model.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';

import '../../../../core/database/fixtures.dart';
import '../../fixtures.dart';

/// Answers each call with the configured model, or throws [error].
class _FakeRemote() implements GroupRemoteDataSource {
  List<GroupSummaryModel> list = [];
  GroupModel group = GroupModel.fromJson(groupJson);
  Object? error;

  Future<T> _answer<T>(T value) async {
    if (error case final e?) throw e;
    return value;
  }

  @override
  Future<List<GroupSummaryModel>> listMyGroups(String status) => _answer(list);

  @override
  Future<GroupModel> getGroup(String id) => _answer(group);

  @override
  Future<GroupModel> createGroup(CreateGroupRequestModel body) => _answer(group);

  @override
  Future<GroupModel> updateGroup(String id, UpdateGroupRequestModel body) => _answer(group);

  @override
  Future<GroupModel> closeGroup(String id) => _answer(group);

  @override
  Future<GroupModel> updatePaymentInfo(String id, PaymentInfoRequestModel body) => _answer(group);

  @override
  Future<GroupModel> uploadQris(String id, String path) => _answer(group);

  @override
  Future<void> deleteQris(String id) => _answer(null);
}

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late GroupRepositoryImpl repository;

  setUp(() {
    db = openTestDatabase();
    remote = _FakeRemote();
    repository = GroupRepositoryImpl(remote, GroupLocalDataSourceImpl(db.groupsDao));
  });
  tearDown(() => db.close());

  test('refresh writes rows the watch stream then emits', () async {
    // Arrange
    remote.list = [GroupSummaryModel.fromJson(summaryJson('g1'))];
    final emissions = repository.watchMyGroups(GroupListFilter.active);

    // Act
    await repository.refreshMyGroups(GroupListFilter.active);

    // Assert
    final groups = (await emissions.first).getOrElse((_) => []);
    expect(groups.single.id, 'g1');
    expect(groups.single.myPaymentStatus, PaymentStatus.unpaid);
    expect(groups.single.nextDueDate, DateTime.utc(2026, 11, 25));
  });

  test('server row replaces a stale cached row', () async {
    // Arrange
    await db.groupsDao.upsertAll([groupRow('g1', name: 'Lama')]);
    remote.list = [GroupSummaryModel.fromJson(summaryJson('g1', name: 'Baru'))];

    // Act
    await repository.refreshMyGroups(GroupListFilter.active);

    // Assert
    final groups = (await repository.watchMyGroups(GroupListFilter.active).first).getOrElse((_) => []);
    expect(groups.single.name, 'Baru');
  });

  test('refreshing the active list keeps cached finished groups', () async {
    // Arrange
    await db.groupsDao.upsertAll([
      groupRow('done').copyWith(status: const Value('completed')),
      groupRow('stale'),
    ]);
    remote.list = [GroupSummaryModel.fromJson(summaryJson('g1'))];

    // Act
    await repository.refreshMyGroups(GroupListFilter.active);

    // Assert
    final all = (await repository.watchMyGroups(GroupListFilter.all).first).getOrElse((_) => []);
    expect(all.map((g) => g.id), unorderedEquals(['g1', 'done']));
  });

  test('a detail refresh keeps the card numbers from the list', () async {
    // Arrange
    remote.list = [GroupSummaryModel.fromJson(summaryJson(groupJson['id'] as String))];
    await repository.refreshMyGroups(GroupListFilter.active);

    // Act
    final fresh = await repository.refreshGroup(groupJson['id'] as String);

    // Assert
    expect(fresh.getOrElse((_) => throw StateError('')).paymentInfo?.qrisImageUrl, isNotNull);
    final cached = (await repository.watchGroup(groupJson['id'] as String).first).getOrElse((_) => null);
    expect(cached?.status, GroupStatus.draft);
    expect(cached?.paidCount, 4);
    expect(cached?.paymentInfo?.hasQris, isTrue);
    expect(cached?.paymentInfo?.qrisImageUrl, isNull);
  });

  test('a 404 on refresh drops the cached group', () async {
    // Arrange
    await db.groupsDao.upsertAll([groupRow('g1')]);
    remote.error = const NotFoundException();

    // Act
    final result = await repository.refreshGroup('g1');

    // Assert
    expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
    expect(await db.groupsDao.getById('g1'), isNull);
  });
}
