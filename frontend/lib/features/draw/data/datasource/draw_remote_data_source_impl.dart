import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/idempotency.dart';
import 'draw_remote_data_source.dart';
import 'model/draw_model.dart';

part 'draw_remote_data_source_impl.g.dart';

typedef _Json = Map<String, dynamic>;

class DrawRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements DrawRemoteDataSource {
  @override
  Future<DrawModel> getDraw(String groupId, String periodId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.draw(groupId, periodId));
    return _one(response);
  });

  @override
  Future<DrawModel> runDraw(
    String groupId,
    String periodId, {
    bool confirmIncomplete = false,
    required IdempotencyKey key,
  }) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.draw(groupId, periodId),
      data: {if (confirmIncomplete) 'confirm_incomplete': true},
      options: Options(extra: {ApiEndpoints.kIdempotencyKey: key.value}),
    );
    return _one(response);
  });

  static DrawModel _one(Response<_Json> response) {
    final data = response.data?['data'];
    if (data is! _Json) throw UnknownException('Empty ${response.requestOptions.path} response');
    return DrawModel.fromJson(data);
  }
}

@Riverpod(keepAlive: true)
DrawRemoteDataSource drawRemoteDataSource(Ref ref) => DrawRemoteDataSourceImpl(ref.watch(dioProvider));
