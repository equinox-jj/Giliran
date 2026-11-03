import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/group/domain/usecases/filter_groups_usecase.dart';

import '../../../../helpers/group_fixtures.dart';

void main() {
  final groups = [
    summary('org', role: MemberRole.organizer),
    summary('co', role: MemberRole.coOrganizer, payment: PaymentStatus.rejected),
    summary('mem', payment: PaymentStatus.unpaid),
    summary('none', payment: null),
  ];

  final cases = <GroupChipFilter, List<String>>{
    GroupChipFilter.all: ['org', 'co', 'mem', 'none'],
    GroupChipFilter.managing: ['org', 'co'],
    GroupChipFilter.member: ['mem', 'none'],
    GroupChipFilter.unpaid: ['co', 'mem'],
  };
  for (final MapEntry(key: filter, value: ids) in cases.entries) {
    test('${filter.name} keeps ${ids.join(', ')}', () {
      // Act
      final result = const FilterGroupsUseCase()((groups: groups, filter: filter));

      // Assert
      expect(result.map((g) => g.id), ids);
    });
  }
}
