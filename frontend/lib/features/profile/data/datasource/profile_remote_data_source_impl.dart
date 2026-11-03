import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import 'model/profile_model.dart';
import 'model/update_me_request_model.dart';
import 'profile_remote_data_source.dart';

part 'profile_remote_data_source_impl.g.dart';

class ProfileRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements ProfileRemoteDataSource {
  @override
  Future<ProfileDataModel> getMe() => safeApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
    return _user(response);
  });

  @override
  Future<ProfileDataModel> updateMe(UpdateMeRequestModel body) => safeApiCall(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.me,
      data: body.toJson(),
    );
    return _user(response);
  });

  @override
  Future<ProfileDataModel> uploadAvatar(
    String path, {
    void Function(double progress)? onProgress,
  }) => safeApiCall(() async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: p.basename(path),
        // Dio sends octet-stream by default, which the API rejects with 415.
        contentType: _imageType(path),
      ),
    });
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.meAvatar,
      data: form,
      onSendProgress: onProgress == null
          ? null
          : (sent, total) => onProgress(total > 0 ? (sent / total).clamp(0.0, 1.0) : 0),
    );
    return _user(response);
  });

  @override
  Future<void> deleteAvatar() => safeApiCall(() async {
    await _dio.delete<void>(ApiEndpoints.meAvatar);
  });

  static DioMediaType _imageType(String path) => switch (p.extension(path).toLowerCase()) {
    '.png' => DioMediaType('image', 'png'),
    '.webp' => DioMediaType('image', 'webp'),
    _ => DioMediaType('image', 'jpeg'),
  };

  ProfileDataModel _user(Response<Map<String, dynamic>> response) {
    final body = response.data;
    final user = body == null
        ? null
        : ApiResponse<ProfileDataModel>.fromJson(
            body,
            (json) => ProfileDataModel.fromJson(json! as Map<String, dynamic>),
          ).data;
    if (user == null) throw const UnknownException('Empty /me response');
    return user;
  }
}

@Riverpod(keepAlive: true)
ProfileRemoteDataSource profileRemoteDataSource(Ref ref) => ProfileRemoteDataSourceImpl(ref.watch(dioProvider));
