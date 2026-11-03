import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/group/presentation/create_group/controllers/create_group_controller.dart';
import 'package:giliran/features/group/presentation/create_group/page/create_group_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late ProviderContainer container;
  late List<String> created;

  setUp(() {
    groups = FakeGroupRepository();
    created = [];
  });

  Future<void> pumpCreate(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(CreateGroupPage(onCreated: created.add), container: container);
    await tester.pumpAndSettle();
  }

  Future<void> fillBasics(WidgetTester tester) async {
    await tester.enterText(find.byType(AppTextField).first, 'Arisan RT 05');
    await tester.enterText(find.byType(AmountField), '200000');
    await tester.pumpAndSettle();
  }

  AppButton primary(WidgetTester tester) => tester.widget<AppButton>(find.byType(AppButton).last);

  testWidgets('the live summary multiplies dues by slots', (tester) async {
    // Arrange
    await pumpCreate(tester);

    // Act
    await fillBasics(tester);

    // Assert
    expect(find.text('Total per periode'), findsOneWidget);
    expect(find.text('Rp2.000.000'), findsOneWidget);
  });

  testWidgets('the slots helper counts periods, then adds the last due date', (tester) async {
    // Arrange
    await pumpCreate(tester);
    await fillBasics(tester);
    final before = find.text('10 periode').evaluate().isNotEmpty;
    final notifier = container.read(createGroupControllerProvider().notifier);

    // Act
    notifier
      ..setPeriodType(PeriodType.weekly)
      ..setTotalSlots(8)
      ..setStartDate(DateTime.utc(2026, 11));
    await tester.pumpAndSettle();

    // Assert
    expect(before, isTrue);
    expect(find.text('8 periode · selesai Min, 20 Des 2026'), findsOneWidget);
  });

  testWidgets('Lanjut is disabled while the basics are invalid', (tester) async {
    // Arrange
    await pumpCreate(tester);
    final emptyDisabled = primary(tester).onPressed == null;

    // Act
    await tester.enterText(find.byType(AppTextField).first, 'Arisan RT 05');
    await tester.enterText(find.byType(AmountField), '9999');
    await tester.pumpAndSettle();

    // Assert
    expect(emptyDisabled, isTrue);
    expect(primary(tester).onPressed, isNull);
    expect(find.text('Iuran Rp10.000 sampai Rp100.000.000.'), findsOneWidget);
  });

  testWidgets('Ubah on the review returns to step 1 with the values kept', (tester) async {
    // Arrange
    await pumpCreate(tester);
    await fillBasics(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    final onStep2 = find.text('2 dari 2').evaluate().isNotEmpty;

    // Act
    await tester.ensureVisible(find.widgetWithText(AppTextButton, 'Ubah langkah 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppTextButton, 'Ubah langkah 1'));
    await tester.pumpAndSettle();

    // Assert
    expect(onStep2, isTrue);
    expect(find.text('1 dari 2'), findsOneWidget);
    expect(find.text('Arisan RT 05'), findsOneWidget);
    expect(find.text('200.000'), findsOneWidget);
  });

  testWidgets('the reminder defaults to 2 days', (tester) async {
    // Arrange
    await pumpCreate(tester);
    await fillBasics(tester);

    // Act
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Assert
    final stepper = tester.widget<AppStepper>(find.widgetWithText(AppStepper, 'Pengingat'));
    expect((stepper.value, stepper.min, stepper.max), (2, 0, 7));
    expect(find.text('Hari sebelum jatuh tempo, ke anggota yang belum bayar.'), findsOneWidget);
  });

  testWidgets('a 422 on a basics field shows under it on step 1', (tester) async {
    // Arrange
    groups.groupResult = const Left(
      Failure.validation(
        fieldErrors: [FieldError(field: 'name', code: 'duplicate', message: 'Nama sudah dipakai.')],
      ),
    );
    await pumpCreate(tester);
    await fillBasics(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    container.read(createGroupControllerProvider().notifier).setStartDate(DateTime.utc(2026, 11, 25));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Buat grup'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('1 dari 2'), findsOneWidget);
    expect(find.text('Nama sudah dipakai.'), findsOneWidget);
    expect(created, isEmpty);
  });

  testWidgets('success hands over the new group id', (tester) async {
    // Arrange
    groups.groupResult = const Right(GroupDetail(id: 'g-new'));
    await pumpCreate(tester);
    await fillBasics(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    container.read(createGroupControllerProvider().notifier).setStartDate(DateTime.utc(2026, 11, 25));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Buat grup'));
    await tester.pumpAndSettle();

    // Assert
    expect(created, ['g-new']);
    expect(groups.lastCreate?.amount, 200000);
    expect(groups.lastCreate?.startDate, DateTime.utc(2026, 11, 25));
  });
}
