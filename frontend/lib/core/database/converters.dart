import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a JSON object (activity log `before` / `after`) as a TEXT column.
class JsonMapConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonMapConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map).cast<String, Object?>();

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);
}
