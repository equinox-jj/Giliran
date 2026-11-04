import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/history/data/datasource/notification_remote_data_source_impl.dart';

class _RecordingAdapter() implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('putPushToken sends PUT /me/push-token with fcm_token', () async {
    // Arrange
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;

    // Act
    await NotificationRemoteDataSourceImpl(dio).putPushToken('fcm-1');

    // Assert
    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/me/push-token');
    expect(jsonEncode(request.data), jsonEncode({'fcm_token': 'fcm-1'}));
  });
}
