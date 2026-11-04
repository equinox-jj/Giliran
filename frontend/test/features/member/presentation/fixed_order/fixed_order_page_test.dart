import 'dart:math';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/usecases/shuffle_order_usecase.dart';
import 'package:giliran/features/member/presentation/fixed_order/page/fixed_order_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';

import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

const _members = [
  Member(id: 'm1', displayName: 'Rina', slotNo: 1, slotId: 'slot-1'),
  Member(id: 'm2', displayName: 'Dedi', slotNo: 2, slotId: 'slot-2'),
  Member(id: 'm3', displayName: 'Sri', slotNo: 3, slotId: 'slot-3'),
];

void main() {
  late FakeGroupRepository groups;
  late FakeMemberRepository members;
  late List<String> events;

  setUp(() {
    groups = FakeGroupRepository();
    members = FakeMemberRepository()..members = _members;
    events = [];
  });

  Future<void> pumpFixedOrder(WidgetTester tester, {GroupStatus status = GroupStatus.draft}) async {
    groups
      ..group = GroupDetail(
        id: 'g1',
        name: 'Arisan RT 05',
        totalSlots: 3,
        filledSlots: 3,
        status: status,
        drawMethod: DrawMethod.fixedOrder,
        myRole: MemberRole.organizer,
      )
      ..groupResult = null;
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        memberRepositoryProvider.overrideWithValue(members),
        shuffleOrderUseCaseProvider.overrideWithValue(ShuffleOrderUseCase(Random(1))),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      FixedOrderPage(groupId: 'g1', onDone: () => events.add('done')),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  List<String> names(WidgetTester tester) => [
    for (final row in tester.widgetList<ReorderableMemberRow>(find.byType(ReorderableMemberRow))) row.name,
  ];

  void performAction(WidgetTester tester, String row, String action) {
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp(row)));
    final id = CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: action));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.customAction,
        viewId: tester.view.viewId,
        nodeId: node.id,
        arguments: id,
      ),
    );
  }

  testWidgets('Turunkan moves a row one place down', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();
    await pumpFixedOrder(tester);

    // Act
    performAction(tester, 'Urutan 1: Rina', 'Turunkan');
    await tester.pumpAndSettle();

    // Assert
    expect(names(tester), ['Dedi', 'Rina', 'Sri']);
    handle.dispose();
  });

  testWidgets('Naikkan moves a row one place up', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();
    await pumpFixedOrder(tester);

    // Act
    performAction(tester, 'Urutan 3: Sri', 'Naikkan');
    await tester.pumpAndSettle();

    // Assert
    expect(names(tester), ['Rina', 'Sri', 'Dedi']);
    handle.dispose();
  });

  testWidgets('Acak urutan shuffles the rows', (tester) async {
    // Arrange
    await pumpFixedOrder(tester);
    final before = names(tester);

    // Act
    await tester.tap(find.text('Acak urutan'));
    await tester.pumpAndSettle();

    // Assert
    expect(names(tester), isNot(before));
    expect(names(tester), unorderedEquals(before));
  });

  testWidgets('saving sends every slot with its new position', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();
    await pumpFixedOrder(tester);
    performAction(tester, 'Urutan 1: Rina', 'Turunkan');
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('Simpan urutan'));
    await tester.pumpAndSettle();

    // Assert
    expect(members.lastOrder?.map((e) => (e.slotId, e.position)), [('slot-2', 1), ('slot-1', 2), ('slot-3', 3)]);
    handle.dispose();
  });

  testWidgets('leaving with unsaved changes asks to save', (tester) async {
    // Arrange
    await pumpFixedOrder(tester);
    await tester.tap(find.text('Acak urutan'));
    await tester.pumpAndSettle();

    // Act
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Simpan perubahan?'), findsOneWidget);
  });

  testWidgets('a started group shows the locked banner and no save', (tester) async {
    // Act
    await pumpFixedOrder(tester, status: GroupStatus.active);

    // Assert
    expect(find.text('Urutan dikunci setelah arisan dimulai'), findsOneWidget);
    expect(find.text('Simpan urutan'), findsNothing);
    expect(find.text('Acak urutan'), findsNothing);
  });
}
