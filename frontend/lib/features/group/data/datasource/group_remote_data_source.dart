import 'model/group_model.dart';
import 'model/group_request_model.dart';
import 'model/group_summary_model.dart';

/// The group endpoints of the API.
abstract interface class GroupRemoteDataSource() {
  /// `GET /me/groups?status=`.
  Future<List<GroupSummaryModel>> listMyGroups(String status);

  /// `GET /groups/{id}`.
  Future<GroupModel> getGroup(String id);

  /// `POST /groups`.
  Future<GroupModel> createGroup(CreateGroupRequestModel body);

  /// `PATCH /groups/{id}`.
  Future<GroupModel> updateGroup(String id, UpdateGroupRequestModel body);

  /// `POST /groups/{id}/close`.
  Future<GroupModel> closeGroup(String id);

  /// `PUT /groups/{id}/payment-info`.
  Future<GroupModel> updatePaymentInfo(String id, PaymentInfoRequestModel body);

  /// `PUT /groups/{id}/payment-info/qris`: uploads the image at [path] as
  /// multipart `file`.
  Future<GroupModel> uploadQris(String id, String path);

  /// `DELETE /groups/{id}/payment-info/qris`.
  Future<void> deleteQris(String id);
}
