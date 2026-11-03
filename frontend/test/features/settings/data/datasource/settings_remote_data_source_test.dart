import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/settings/data/datasource/model/user_settings_model.dart';
import 'package:giliran/features/settings/data/datasource/settings_remote_data_source_impl.dart';

/// Records each request and answers with [body].
class _RecordingAdapter() implements HttpClientAdapter {
  Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _settingsJson = {
  'language': 'id',
  'notify_payment_reminders': true,
  'notify_draw_results': false,
  'notify_group_activity': true,
};

void main() {
  late _RecordingAdapter adapter;
  late SettingsRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter()..body = {'data': _settingsJson};
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = SettingsRemoteDataSourceImpl(dio);
  });

  test('getSettings parses the envelope', () async {
    // Arrange
    final expected = UserSettingsModel.fromJson(_settingsJson);

    // Act
    final settings = await dataSource.getSettings();

    // Assert
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/me/settings');
    expect(settings, expected);
  });

  test('updateSettings sends only the changed field', () async {
    // Arrange
    const body = UpdateSettingsRequestModel(notifyDrawResults: true);

    // Act
    await dataSource.updateSettings(body);

    // Assert
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/me/settings');
    expect(adapter.requests.single.data, {'notify_draw_results': true});
  });
}
