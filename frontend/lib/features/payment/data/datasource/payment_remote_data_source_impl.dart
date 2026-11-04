import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/idempotency.dart';
import 'model/payment_model.dart';
import 'model/payout_model.dart';
import 'model/period_model.dart';
import 'payment_remote_data_source.dart';

part 'payment_remote_data_source_impl.g.dart';

typedef _Json = Map<String, dynamic>;

class PaymentRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements PaymentRemoteDataSource {
  @override
  Future<List<PeriodModel>> listPeriods(String groupId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.periods(groupId));
    return _list(response, PeriodModel.fromJson);
  });

  @override
  Future<PeriodModel> getPeriod(String groupId, String periodId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.period(groupId, periodId));
    return _one(response, PeriodModel.fromJson);
  });

  @override
  Future<PaymentBoardModel> getPaymentBoard(String groupId, String periodId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.periodPayments(groupId, periodId));
    final meta = response.data?['meta'];
    final summary = meta is _Json ? meta['summary'] : null;
    return (
      payments: _list(response, PaymentModel.fromJson),
      summary: summary is _Json ? PaymentSummaryModel.fromJson(summary) : null,
    );
  });

  @override
  Future<PaymentModel> getPayment(String groupId, String paymentId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.payment(groupId, paymentId));
    return _one(response, PaymentModel.fromJson);
  });

  @override
  Future<PaymentModel> uploadProof(
    String groupId,
    String paymentId,
    String path, {
    required IdempotencyKey key,
    void Function(double progress)? onProgress,
  }) => safeApiCall(() async {
    final form = FormData.fromMap({'file': await _image(path)});
    final response = await _dio.post<_Json>(
      ApiEndpoints.paymentProofs(groupId, paymentId),
      data: form,
      options: _write(key),
      onSendProgress: onProgress == null ? null : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
    );
    return _one(response, PaymentModel.fromJson);
  });

  @override
  Future<PaymentModel> approvePayment(String groupId, String paymentId, {required IdempotencyKey key}) =>
      safeApiCall(() async {
        final response = await _dio.post<_Json>(ApiEndpoints.paymentApprove(groupId, paymentId), options: _write(key));
        return _one(response, PaymentModel.fromJson);
      });

  @override
  Future<PaymentModel> rejectPayment(
    String groupId,
    String paymentId, {
    required String reason,
    required IdempotencyKey key,
  }) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.paymentReject(groupId, paymentId),
      data: {'reason': reason},
      options: _write(key),
    );
    return _one(response, PaymentModel.fromJson);
  });

  @override
  Future<PaymentModel> markPaid(
    String groupId,
    String paymentId, {
    required String method,
    String? note,
    DateTime? paidAt,
    required IdempotencyKey key,
  }) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.paymentMarkPaid(groupId, paymentId),
      data: {'method': method, 'note': ?note, 'paid_at': ?paidAt?.toUtc().toIso8601String()},
      options: _write(key),
    );
    return _one(response, PaymentModel.fromJson);
  });

  @override
  Future<PayoutModel> getPayout(String groupId, String periodId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.payout(groupId, periodId));
    return _one(response, PayoutModel.fromJson);
  });

  @override
  Future<PayoutModel> recordPayout(
    String groupId,
    String periodId, {
    String? proofPath,
    String? note,
    required IdempotencyKey key,
  }) => safeApiCall(() async {
    final form = FormData.fromMap({
      if (proofPath != null) 'file': await _image(proofPath),
      'note': ?note,
    });
    final response = await _dio.post<_Json>(ApiEndpoints.payout(groupId, periodId), data: form, options: _write(key));
    return _one(response, PayoutModel.fromJson);
  });

  @override
  Future<PayoutModel> confirmPayout(String groupId, String periodId, {required IdempotencyKey key}) =>
      safeApiCall(() async {
        final response = await _dio.post<_Json>(ApiEndpoints.payoutConfirm(groupId, periodId), options: _write(key));
        return _one(response, PayoutModel.fromJson);
      });

  static Options _write(IdempotencyKey key) => Options(extra: {ApiEndpoints.kIdempotencyKey: key.value});

  // Dio sends octet-stream by default, which the API rejects with 415.
  static Future<MultipartFile> _image(String path) => MultipartFile.fromFile(
    path,
    filename: p.basename(path),
    contentType: switch (p.extension(path).toLowerCase()) {
      '.png' => DioMediaType('image', 'png'),
      _ => DioMediaType('image', 'jpeg'),
    },
  );

  static T _one<T>(Response<_Json> response, T Function(_Json) parse) {
    final data = response.data?['data'];
    if (data is! _Json) throw UnknownException('Empty ${response.requestOptions.path} response');
    return parse(data);
  }

  static List<T> _list<T>(Response<_Json> response, T Function(_Json) parse) {
    final data = response.data?['data'];
    if (data is! List) throw UnknownException('Empty ${response.requestOptions.path} response');
    return [for (final item in data) parse(item as _Json)];
  }
}

@Riverpod(keepAlive: true)
PaymentRemoteDataSource paymentRemoteDataSource(Ref ref) => PaymentRemoteDataSourceImpl(ref.watch(dioProvider));
