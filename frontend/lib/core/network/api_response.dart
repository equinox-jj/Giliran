/// Envelope for a single-object API response: `{"data": …, "message"?}`.
///
/// The generic `T` is decoded through a caller-supplied `fromJsonT`
/// converter, so it works with json_serializable models.
class ApiResponse<T> {
  const ApiResponse({this.data, this.message});

  /// Parses [json], decoding the `data` member with [fromJsonT].
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final rawData = json['data'];
    return ApiResponse<T>(
      data: rawData == null ? null : fromJsonT(rawData),
      message: json['message'] as String?,
    );
  }

  /// The decoded payload, or null when the body carried no `data`.
  final T? data;

  /// Optional feedback from the server, sent only when it adds something.
  final String? message;
}

/// Envelope for a cursor-paginated list:
/// `{"data": [...], "meta": {"next_cursor": "…", "has_more": true}}`.
class CursorPage<T> {
  const CursorPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Parses [json], decoding each element of `data` with [fromJsonT].
  factory CursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final rawList = json['data'] as List<dynamic>? ?? const <dynamic>[];
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return CursorPage<T>(
      items: rawList.map(fromJsonT).toList(growable: false),
      nextCursor: meta['next_cursor'] as String?,
      hasMore: meta['has_more'] as bool? ?? false,
    );
  }

  /// Decoded page items. Empty lists come back as `[]`, never null.
  final List<T> items;

  /// Pass as `cursor` to fetch the next page; null on the last page.
  final String? nextCursor;

  /// True when another page exists.
  final bool hasMore;
}
