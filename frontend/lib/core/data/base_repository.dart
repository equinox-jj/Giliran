import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../error/error_mapper.dart';

/// Mixed into repository implementations to centralize the try/catch that
/// converts thrown exceptions into a domain [Failure]. This is the single
/// boundary where exceptions stop and `Either` begins.
mixin BaseRepository {
  /// Runs [body], returning `Right` on success or `Left(Failure)` on any
  /// exception. [Error]s are programming bugs and are rethrown.
  Future<Either<Failure, T>> safeCall<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on Error {
      rethrow;
    } on Object catch (e, st) {
      return Left(mapExceptionToFailure(e, st));
    }
  }

  /// Like [safeCall], for streams such as Drift watch queries: each value
  /// becomes `Right`, each exception a `Left(Failure)`, and the stream keeps
  /// going. [Error]s are rethrown.
  Stream<Either<Failure, T>> safeStream<T>(Stream<T> stream) => stream
      .map<Either<Failure, T>>(Right.new)
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) {
            if (error is Error) {
              sink.addError(error, stackTrace);
            } else {
              sink.add(Left(mapExceptionToFailure(error, stackTrace)));
            }
          },
        ),
      );
}
