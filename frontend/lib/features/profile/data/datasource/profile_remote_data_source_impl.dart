import 'package:dio/dio.dart';
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

class ProfileRemoteDataSourceImpl with BaseRemoteDataSource implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._dio);

  final Dio _dio;

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
