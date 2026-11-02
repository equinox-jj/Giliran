import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/features/profile/data/datasource/model/update_me_request_model.dart';
import 'package:giliran/features/profile/data/datasource/profile_remote_data_source_impl.dart';

/// Records each request and answers with [status] and [body].
class _RecordingAdapter() implements HttpClientAdapter {
  int status = 200;
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
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _userJson = {
  'id': 'user-1',
  'email': 'joshua@email.com',
  'phone': '+6281234567890',
  'name': 'Joshua',
  'avatar_url': null,
  'pin_set': false,
  'created_at': '2026-11-02T08:00:00Z',
};

void main() {
  late _RecordingAdapter adapter;
  late ProfileRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = ProfileRemoteDataSourceImpl(dio);
  });

  test('getMe parses the profile envelope', () async {
    // Arrange
    adapter.body = {'data': _userJson};

    // Act
    final user = await dataSource.getMe();

    // Assert
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/me');
    expect(user.name, 'Joshua');
    expect(user.phone, '+6281234567890');
    expect(user.pinSet, isFalse);
  });

  test('updateMe patches only the fields that are set', () async {
    // Arrange
    adapter.body = {'data': _userJson};

    // Act
    await dataSource.updateMe(const UpdateMeRequestModel(name: 'Joshua'));

    // Assert
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/me');
    expect(adapter.requests.single.data, {'name': 'Joshua'});
  });

  test('updateMe maps 422 to ValidationException with field errors', () async {
    // Arrange
    adapter
      ..status = 422
      ..body = {
        'status': 422,
        'code': 'validation_error',
        'errors': [
          {'field': 'name', 'rule': 'min_length', 'message': 'Terlalu pendek'},
        ],
      };

    // Act
    final call = dataSource.updateMe(const UpdateMeRequestModel(name: 'J'));

    // Assert
    await expectLater(
      call,
      throwsA(
        isA<ValidationException>().having(
          (e) => e.fieldErrors.single.field,
          'field',
          'name',
        ),
      ),
    );
  });
}
