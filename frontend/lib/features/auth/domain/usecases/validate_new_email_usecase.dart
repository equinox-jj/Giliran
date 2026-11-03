import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/problem_details.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'validate_new_email_usecase.g.dart';

/// Step 1 of S46: checks the new address before asking for the PIN and
/// returns it trimmed and lowercased. Fails with a `validation_error` on
/// `email` with code [sameEmailCode] when it is the account's address now.
/// Whether it already has an account is left to the server (`409`).
class ValidateNewEmailUseCase(final AuthRepository _repository) implements UseCase<String, String> {
  static const sameEmailCode = 'same_email';

  @override
  Future<Either<Failure, String>> call(String email) async {
    final normalized = email.trim().toLowerCase();
    final user = await _repository.readCurrentUser();

    return user.flatMap((user) {
      final current = user?.email?.trim().toLowerCase();
      if (current != null && current == normalized) {
        return const Left(
          Failure.validation(
            fieldErrors: [
              FieldError(field: 'email', code: sameEmailCode, message: 'Ini email kamu yang sekarang.'),
            ],
          ),
        );
      }
      return Right(normalized);
    });
  }
}

@riverpod
ValidateNewEmailUseCase validateNewEmailUseCase(Ref ref) => ValidateNewEmailUseCase(ref.watch(authRepositoryProvider));
