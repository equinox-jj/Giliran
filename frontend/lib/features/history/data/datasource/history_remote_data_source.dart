import '../../../../core/network/api_response.dart';
import 'model/activity_entry_model.dart';

/// The activity log on the API, newest first, paged by an opaque cursor.
abstract interface class HistoryRemoteDataSource() {
  static const pageSize = 30;

  Future<CursorPage<ActivityEntryModel>> getActivity(String groupId, {String? cursor, int limit = pageSize});
}
