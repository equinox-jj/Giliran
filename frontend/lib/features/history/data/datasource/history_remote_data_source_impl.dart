import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import 'history_remote_data_source.dart';
import 'model/activity_entry_model.dart';

part 'history_remote_data_source_impl.g.dart';

class HistoryRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements HistoryRemoteDataSource {
  @override
  Future<CursorPage<ActivityEntryModel>> getActivity(
    String groupId, {
    String? cursor,
    int limit = HistoryRemoteDataSource.pageSize,
  }) => safeApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.activity(groupId),
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    return CursorPage.fromJson(
      response.data ?? const {},
      (json) => ActivityEntryModel.fromJson(json! as Map<String, dynamic>),
    );
  });
}

@Riverpod(keepAlive: true)
HistoryRemoteDataSource historyRemoteDataSource(Ref ref) => HistoryRemoteDataSourceImpl(ref.watch(dioProvider));
