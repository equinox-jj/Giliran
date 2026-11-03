import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// The current instant. Controllers read "now" through this so tests can pin
/// it.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
