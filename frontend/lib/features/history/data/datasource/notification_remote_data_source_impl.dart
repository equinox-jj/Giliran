import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import 'notification_remote_data_source.dart';

part 'notification_remote_data_source_impl.g.dart';

class NotificationRemoteDataSourceImpl(final Dio _dio)
    with BaseRemoteDataSource
    implements NotificationRemoteDataSource {
  @override
  Future<void> putPushToken(String token) => safeApiCall(() async {
    await _dio.put<void>(ApiEndpoints.mePushToken, data: {'fcm_token': token});
  });
}

@Riverpod(keepAlive: true)
NotificationRemoteDataSource notificationRemoteDataSource(Ref ref) =>
    NotificationRemoteDataSourceImpl(ref.watch(dioProvider));
