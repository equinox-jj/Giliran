import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/idempotency.dart';
import 'model/recap_model.dart';
import 'model/reminder_result_model.dart';
import 'reminder_remote_data_source.dart';

part 'reminder_remote_data_source_impl.g.dart';

typedef _Json = Map<String, dynamic>;

class ReminderRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements ReminderRemoteDataSource {
  @override
  Future<RecapModel> getRecap(String groupId, String periodId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.recap(groupId, periodId));
    return RecapModel.fromJson(_data(response));
  });

  @override
  Future<ReminderResultModel> sendReminders(
    String groupId,
    String periodId, {
    List<String>? memberIds,
    required IdempotencyKey key,
  }) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.reminders(groupId, periodId),
      data: {'member_ids': ?memberIds},
      options: Options(extra: {ApiEndpoints.kIdempotencyKey: key.value}),
    );
    return ReminderResultModel.fromJson(_data(response));
  });

  static _Json _data(Response<_Json> response) {
    final data = response.data?['data'];
    if (data is! _Json) throw UnknownException('Empty ${response.requestOptions.path} response');
    return data;
  }
}

@Riverpod(keepAlive: true)
ReminderRemoteDataSource reminderRemoteDataSource(Ref ref) => ReminderRemoteDataSourceImpl(ref.watch(dioProvider));
