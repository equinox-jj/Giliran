import 'dart:convert';
import 'dart:io';
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

  test('updateMe with clearPhone sends phone null', () async {
    // Arrange
    adapter.body = {'data': _userJson};

    // Act
    await dataSource.updateMe(const UpdateMeRequestModel(), clearPhone: true);

    // Assert
    expect(adapter.requests.single.data, {'phone': null});
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

  test('getSessions parses the list, current one first', () async {
    // Arrange
    adapter.body = {
      'data': [
        {
          'id': 's-1',
          'device_name': 'Pixel 8',
          'device_platform': 'android',
          'last_active_at': '2026-11-03T08:00:00Z',
          'created_at': '2026-11-01T08:00:00Z',
          'is_current': true,
        },
        {
          'id': 's-2',
          'device_name': null,
          'device_platform': 'ios',
          'last_active_at': '2026-11-02T08:00:00Z',
          'created_at': '2026-10-01T08:00:00Z',
          'is_current': false,
        },
      ],
    };

    // Act
    final sessions = await dataSource.getSessions();

    // Assert
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/me/sessions');
    expect(sessions.map((s) => s.id), ['s-1', 's-2']);
    expect(sessions.first.isCurrent, isTrue);
    expect(sessions.last.devicePlatform, 'ios');
    expect(sessions.last.deviceName, isNull);
  });

  test('revokeSession deletes that session', () async {
    // Arrange
    adapter.status = 204;

    // Act
    await dataSource.revokeSession('s-2');

    // Assert
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/me/sessions/s-2');
  });

  test('deleteAccount posts the PIN', () async {
    // Arrange
    adapter.status = 204;

    // Act
    await dataSource.deleteAccount('123456');

    // Assert
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/me/deletion');
    expect(adapter.requests.single.data, {'pin': '123456'});
  });

  test('deleteAccount maps obligations_outstanding to a conflict', () async {
    // Arrange
    adapter
      ..status = 409
      ..body = {'status': 409, 'code': 'obligations_outstanding'};

    // Act
    final call = dataSource.deleteAccount('123456');

    // Assert
    await expectLater(call, throwsA(isA<AppException>()));
  });

  group('uploadAvatar', () {
    late File image;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('avatar_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      image = File('${dir.path}/photo.png')..writeAsBytesSync(List.filled(64, 1));
    });

    test('puts the file as multipart with an image content type', () async {
      // Arrange
      adapter.body = {
        'data': {..._userJson, 'avatar_url': 'https://cdn.test/a.png'},
      };

      // Act
      final user = await dataSource.uploadAvatar(image.path);

      // Assert
      final request = adapter.requests.single;
      final file = (request.data as FormData).files.single;
      expect(request.method, 'PUT');
      expect(request.path, '/me/avatar');
      expect(file.key, 'file');
      expect(file.value.filename, 'photo.png');
      expect(file.value.contentType?.mimeType, 'image/png');
      expect(user.avatarUrl, 'https://cdn.test/a.png');
    });

    test('maps 413 to BadRequestException', () async {
      // Arrange
      adapter
        ..status = 413
        ..body = {'status': 413, 'code': 'file_too_large'};

      // Act
      final call = dataSource.uploadAvatar(image.path);

      // Assert
      await expectLater(call, throwsA(isA<BadRequestException>()));
    });
  });

  test('deleteAvatar sends DELETE to /me/avatar', () async {
    // Arrange
    adapter
      ..status = 204
      ..body = null;

    // Act
    await dataSource.deleteAvatar();

    // Assert
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/me/avatar');
  });
}
