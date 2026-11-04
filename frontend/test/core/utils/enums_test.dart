import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/draw_algorithm.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/draw_status.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/core/utils/enums/period_type.dart';

typedef _Case = (String name, List<Enum> values, String Function(Enum) api, Enum? Function(String?) fromApi);

void main() {
  final cases = <_Case>[
    ('MemberRole', MemberRole.values, (e) => (e as MemberRole).apiValue, MemberRole.fromApi),
    ('DrawMethod', DrawMethod.values, (e) => (e as DrawMethod).apiValue, DrawMethod.fromApi),
    ('PeriodType', PeriodType.values, (e) => (e as PeriodType).apiValue, PeriodType.fromApi),
    ('GroupStatus', GroupStatus.values, (e) => (e as GroupStatus).apiValue, GroupStatus.fromApi),
    ('PeriodStatus', PeriodStatus.values, (e) => (e as PeriodStatus).apiValue, PeriodStatus.fromApi),
    ('PaymentMethod', PaymentMethod.values, (e) => (e as PaymentMethod).apiValue, PaymentMethod.fromApi),
    ('DrawStatus', DrawStatus.values, (e) => (e as DrawStatus).apiValue, DrawStatus.fromApi),
    ('DrawAlgorithm', DrawAlgorithm.values, (e) => (e as DrawAlgorithm).apiValue, DrawAlgorithm.fromApi),
  ];

  for (final (name, values, api, fromApi) in cases) {
    group(name, () {
      test('every value round-trips through its API string', () {
        // Arrange
        final apiValues = values.map(api).toList();

        // Act
        final parsed = apiValues.map(fromApi).toList();

        // Assert
        expect(parsed, values);
      });

      test('unknown and missing values map to null', () {
        // Arrange
        const unknown = 'nope';

        // Act
        final fromUnknown = fromApi(unknown);
        final fromNull = fromApi(null);

        // Assert
        expect(fromUnknown, isNull);
        expect(fromNull, isNull);
      });
    });
  }

  test('multi-word values use the API snake_case strings', () {
    // Arrange
    const role = MemberRole.coOrganizer;
    const method = DrawMethod.fixedOrder;

    // Act
    final values = (role.apiValue, method.apiValue);

    // Assert
    expect(values, ('co_organizer', 'fixed_order'));
  });
}
