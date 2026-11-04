import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../domain/entities/draw.dart';
import '../../domain/repositories/draw_repository.dart';
import '../datasource/draw_remote_data_source.dart';
import '../datasource/draw_remote_data_source_impl.dart';
import '../mappers/draw_mapper.dart';

part 'draw_repository_impl.g.dart';

class DrawRepositoryImpl(final DrawRemoteDataSource _remote) with BaseRepository implements DrawRepository {
  @override
  Future<Either<Failure, Draw>> getDraw(String groupId, String periodId) =>
      safeCall(() async => (await _remote.getDraw(groupId, periodId)).toEntity());

  @override
  Future<Either<Failure, Draw>> runDraw(
    String groupId,
    String periodId, {
    required bool confirmIncomplete,
    required IdempotencyKey key,
  }) => safeCall(
    () async => (await _remote.runDraw(groupId, periodId, confirmIncomplete: confirmIncomplete, key: key)).toEntity(),
  );
}

@Riverpod(keepAlive: true)
DrawRepository drawRepository(Ref ref) => DrawRepositoryImpl(ref.watch(drawRemoteDataSourceProvider));
