import 'package:fpdart/fpdart.dart';

import '../error/failure.dart';

/// Base type for a single business operation in the domain layer.
///
/// [T] is the success value; [Params] is the input (use [NoParams] for none).
/// Use cases depend only on abstract repositories and entities.
abstract interface class UseCase<T, Params>() {
  /// Executes the operation.
  Future<Either<Failure, T>> call(Params params);
}

/// A use case that emits values over time, such as a Drift watch query.
abstract interface class StreamUseCase<T, Params>() {
  /// Starts the stream. Each event is a value or a [Failure].
  Stream<Either<Failure, T>> call(Params params);
}

/// Placeholder for use cases that take no input.
final class const NoParams();
