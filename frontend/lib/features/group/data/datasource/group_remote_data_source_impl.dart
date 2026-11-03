import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import 'group_remote_data_source.dart';
import 'model/group_model.dart';
import 'model/group_request_model.dart';
import 'model/group_summary_model.dart';

part 'group_remote_data_source_impl.g.dart';

class GroupRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements GroupRemoteDataSource {
  @override
  Future<List<GroupSummaryModel>> listMyGroups(String status) => safeApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.meGroups,
      queryParameters: {'status': status},
    );
    final data = response.data?['data'];
    if (data is! List) throw const UnknownException('Empty /me/groups response');
    return [
      for (final item in data) GroupSummaryModel.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<GroupModel> getGroup(String id) => safeApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.group(id));
    return _group(response);
  });

  @override
  Future<GroupModel> createGroup(CreateGroupRequestModel body) => safeApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.groups,
      data: body.toJson(),
    );
    return _group(response);
  });

  @override
  Future<GroupModel> updateGroup(String id, UpdateGroupRequestModel body) => safeApiCall(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.group(id),
      data: body.toJson(),
    );
    return _group(response);
  });

  @override
  Future<GroupModel> closeGroup(String id) => safeApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(ApiEndpoints.groupClose(id));
    return _group(response);
  });

  @override
  Future<GroupModel> updatePaymentInfo(String id, PaymentInfoRequestModel body) => safeApiCall(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.paymentInfo(id),
      data: body.toJson(),
    );
    return _group(response);
  });

  @override
  Future<GroupModel> uploadQris(String id, String path) => safeApiCall(() async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: p.basename(path),
        // Dio sends octet-stream by default, which the API rejects with 415.
        contentType: _imageType(path),
      ),
    });
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.paymentInfoQris(id),
      data: form,
    );
    return _group(response);
  });

  @override
  Future<void> deleteQris(String id) => safeApiCall(() async {
    await _dio.delete<void>(ApiEndpoints.paymentInfoQris(id));
  });

  static DioMediaType _imageType(String path) => switch (p.extension(path).toLowerCase()) {
    '.png' => DioMediaType('image', 'png'),
    _ => DioMediaType('image', 'jpeg'),
  };

  GroupModel _group(Response<Map<String, dynamic>> response) {
    final body = response.data;
    final group = body == null
        ? null
        : ApiResponse<GroupModel>.fromJson(
            body,
            (json) => GroupModel.fromJson(json! as Map<String, dynamic>),
          ).data;
    if (group == null) throw const UnknownException('Empty group response');
    return group;
  }
}

@Riverpod(keepAlive: true)
GroupRemoteDataSource groupRemoteDataSource(Ref ref) => GroupRemoteDataSourceImpl(ref.watch(dioProvider));
