import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'has_session.g.dart';

/// Whether a session may still exist on this device. The splash uses it to
/// pick between unlock and welcome.
class HasSession(final AuthRepository _repository) implements UseCase<bool, NoParams> {
  @override
  Future<Either<Failure, bool>> call(NoParams params) => _repository.hasSession();
}

@riverpod
HasSession hasSession(Ref ref) => HasSession(ref.watch(authRepositoryProvider));
