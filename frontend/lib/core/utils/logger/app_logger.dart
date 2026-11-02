import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../error/failure.dart';
import 'log_redactor.dart';

/// The app logger, built on `package:logging`. Debug builds and
/// `flutter test` only.
///
/// Records go to `Giliran` or `Giliran.<tag>` loggers. Every call is a no-op
/// in profile and release builds; [kDebugMode] is a compile-time constant,
/// so the bodies are tree-shaken out. Messages, `data` and errors are
/// redacted (see `log_redactor.dart`) before they reach a [Logger], but
/// callers still never pass PINs, codes or tokens on purpose.
///
/// Log through this class rather than a raw [Logger], which would skip the
/// redaction.
abstract final class AppLogger() {
  static const rootName = 'Giliran';

  static StreamSubscription<LogRecord>? _subscription;

  /// Enables all levels and forwards records to `dart:developer` in debug
  /// builds; turns logging off otherwise. Call once from `main`. Safe to
  /// call again.
  static void init() {
    if (!kDebugMode) {
      Logger.root.level = Level.OFF;
      return;
    }
    Logger.root.level = Level.ALL;
    _subscription ??= Logger.root.onRecord.listen(_toDeveloper);
  }

  /// Logs a debug message (`Level.FINE`).
  ///
  /// [tag] selects the `Giliran.<tag>` logger. [data] is redacted and appended as
  /// indented JSON.
  static void d(String message, {String? tag, Object? data}) => _log(
    Level.FINE,
    message,
    tag: tag,
    data: data,
  );

  /// Logs an informational message (`Level.INFO`); arguments work as in [d].
  static void i(String message, {String? tag, Object? data}) => _log(
    Level.INFO,
    message,
    tag: tag,
    data: data,
  );

  /// Logs a warning (`Level.WARNING`); arguments work as in [d]. A [Failure]
  /// passed as [error] is described by its code and request id only.
  static void w(
    String message, {
    String? tag,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(
    Level.WARNING,
    message,
    tag: tag,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  /// Logs an error (`Level.SEVERE`); arguments work as in [w].
  static void e(
    String message, {
    String? tag,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(
    Level.SEVERE,
    message,
    tag: tag,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  static void _log(
    Level level,
    String message, {
    String? tag,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    final logger = Logger(tag == null ? rootName : '$rootName.$tag');
    if (!logger.isLoggable(level)) return;
    final text = StringBuffer(scrub(message));
    if (data != null) text.write('\n${_encode(redact(data))}');
    logger.log(
      level,
      text.toString(),
      error == null ? null : _describe(error),
      stackTrace,
    );
  }

  static String _encode(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } on JsonUnsupportedObjectError {
      return scrub('$value');
    }
  }

  /// API failures are described by code and request id only, since
  /// `detail` and `extensions` may echo user input.
  static String _describe(Object error) => switch (error) {
    UnknownFailure(:final cause) || CacheFailure(:final cause) => '${error.runtimeType}(${scrub('$cause')})',
    Failure(:final apiCode?) =>
      '${error.runtimeType}(code: ${apiCode.apiValue}, '
          'requestId: ${error.apiRequestId})',
    _ => scrub('$error'),
  };
}

void _toDeveloper(LogRecord record) => developer.log(
  record.message,
  time: record.time,
  sequenceNumber: record.sequenceNumber,
  name: record.loggerName,
  level: record.level.value,
  error: record.error,
  stackTrace: record.stackTrace,
);
