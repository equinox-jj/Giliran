import 'package:material_ui/material_ui.dart';

import '../errors/exception_mapper.dart' as mapper;

/// Base for repository impls. Wrap every datasource call in [guard] or
/// [guardStream] so only `Failure`s leave the data layer.
abstract class BaseRepository {
  @protected
  Future<T> guard<T>(Future<T> Function() body) => mapper.guard(body);

  @protected
  Stream<T> guardStream<T>(Stream<T> stream) => mapper.guardStream(stream);
}
