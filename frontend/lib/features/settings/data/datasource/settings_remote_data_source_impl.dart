import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import 'model/user_settings_model.dart';
import 'settings_remote_data_source.dart';

part 'settings_remote_data_source_impl.g.dart';

class SettingsRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements SettingsRemoteDataSource {
  @override
  Future<UserSettingsModel> getSettings() => safeApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.meSettings);
    return _settings(response);
  });

  @override
  Future<UserSettingsModel> updateSettings(UpdateSettingsRequestModel body) => safeApiCall(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.meSettings,
      data: body.toJson(),
    );
    return _settings(response);
  });

  UserSettingsModel _settings(Response<Map<String, dynamic>> response) {
    final body = response.data;
    final settings = body == null
        ? null
        : ApiResponse<UserSettingsModel>.fromJson(
            body,
            (json) => UserSettingsModel.fromJson(json! as Map<String, dynamic>),
          ).data;
    if (settings == null) throw const UnknownException('Empty /me/settings response');
    return settings;
  }
}

@Riverpod(keepAlive: true)
SettingsRemoteDataSource settingsRemoteDataSource(Ref ref) => SettingsRemoteDataSourceImpl(ref.watch(dioProvider));
