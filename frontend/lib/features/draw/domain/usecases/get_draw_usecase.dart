import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/draw_repository_impl.dart';
import '../entities/draw.dart';
import '../repositories/draw_repository.dart';

part 'get_draw_usecase.g.dart';

typedef DrawRef = ({String groupId, String periodId});

/// A period's draw: the commitment before it runs, the result after.
class const GetDrawUseCase(final DrawRepository _repository) implements UseCase<Draw, DrawRef> {
  @override
  Future<Either<Failure, Draw>> call(DrawRef params) => _repository.getDraw(params.groupId, params.periodId);
}

@Riverpod(keepAlive: true)
GetDrawUseCase getDrawUseCase(Ref ref) => GetDrawUseCase(ref.watch(drawRepositoryProvider));
