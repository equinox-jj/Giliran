import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/enums/group_list_filter.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_input.dart';
import '../../domain/entities/group_summary.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasource/group_local_data_source.dart';
import '../datasource/group_local_data_source_impl.dart';
import '../datasource/group_remote_data_source.dart';
import '../datasource/group_remote_data_source_impl.dart';
import '../datasource/model/group_model.dart';
import '../mappers/group_mapper.dart';

part 'group_repository_impl.g.dart';

class GroupRepositoryImpl(
  final GroupRemoteDataSource _remote,
  final GroupLocalDataSource _local,
) with BaseRepository implements GroupRepository {
  @override
  Stream<Either<Failure, List<GroupSummary>>> watchMyGroups(GroupListFilter filter) => safeStream(
    _local.watchGroups(filter.statusValues).map((rows) => [for (final row in rows) row.toSummary()]),
  );

  @override
  Future<Either<Failure, Unit>> refreshMyGroups(GroupListFilter filter) => safeCall(() async {
    final groups = await _remote.listMyGroups(filter.apiValue);
    await _local.replaceGroups(
      [for (final group in groups) group.toCompanion()],
      filter.statusValues,
    );
    return unit;
  });

  @override
  Stream<Either<Failure, GroupDetail?>> watchGroup(String id) =>
      safeStream(_local.watchGroup(id).map((row) => row?.toGroup()));

  @override
  Future<Either<Failure, GroupDetail>> refreshGroup(String id) => safeCall(() async {
    try {
      return await _save(await _remote.getGroup(id));
    } on NotFoundException {
      // Removed from the group or the group is gone: drop the stale copy.
      await _local.deleteGroup(id);
      rethrow;
    }
  });

  @override
  Future<Either<Failure, GroupDetail>> createGroup(CreateGroupInput input) =>
      safeCall(() async => _save(await _remote.createGroup(input.toRequest())));

  @override
  Future<Either<Failure, GroupDetail>> updateGroup(String id, UpdateGroupInput input) =>
      safeCall(() async => _save(await _remote.updateGroup(id, input.toRequest())));

  @override
  Future<Either<Failure, GroupDetail>> closeGroup(String id) =>
      safeCall(() async => _save(await _remote.closeGroup(id)));

  @override
  Future<Either<Failure, GroupDetail>> updatePaymentInfo(String id, PaymentInfoInput input) =>
      safeCall(() async => _save(await _remote.updatePaymentInfo(id, input.toRequest())));

  @override
  Future<Either<Failure, GroupDetail>> uploadQris(String id, String path) =>
      safeCall(() async => _save(await _remote.uploadQris(id, path)));

  @override
  Future<Either<Failure, Unit>> deleteQris(String id) => safeCall(() async {
    await _remote.deleteQris(id);
    // The API answers 204, so fetch the group to update the cached flag.
    await _save(await _remote.getGroup(id));
    return unit;
  });

  /// Writes the server's group into the cache and returns it with the
  /// fields only a live response has (the signed QRIS URL).
  Future<GroupDetail> _save(GroupModel model) async {
    await _local.upsertGroup(model.toCompanion());
    return model.toEntity();
  }
}

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) => GroupRepositoryImpl(
  ref.watch(groupRemoteDataSourceProvider),
  ref.watch(groupLocalDataSourceProvider),
);
