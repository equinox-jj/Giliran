import 'package:equatable/equatable.dart';

/// A single piece of application logic in the domain layer.
///
/// Use cases depend only on abstract repositories and entities. Failures are
/// thrown and surface in presentation as `AsyncValue.error` from the calling
/// Riverpod controller.
abstract interface class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// A use case that emits values over time, such as a Drift watch query.
abstract interface class StreamUseCase<T, Params> {
  Stream<T> call(Params params);
}

/// Params for a use case that takes no input.
final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
