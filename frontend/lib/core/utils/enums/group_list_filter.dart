import 'group_status.dart';

/// Which groups `GET /me/groups?status=` returns, and which cached rows a
/// refresh of that list may replace.
enum GroupListFilter(final String apiValue, final Set<GroupStatus> statuses) {
  active('active', {GroupStatus.draft, GroupStatus.active}),
  finished('finished', {GroupStatus.completed, GroupStatus.closed}),
  all('all', {
    GroupStatus.draft,
    GroupStatus.active,
    GroupStatus.completed,
    GroupStatus.closed,
  });

  /// The `groups.status` values this filter covers.
  Set<String> get statusValues => {for (final s in statuses) s.apiValue};
}
