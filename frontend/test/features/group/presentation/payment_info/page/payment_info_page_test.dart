import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/group/presentation/payment_info/page/payment_info_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/fake_image_picker_service.dart';
import '../../../../../helpers/pump_app.dart';

const _info = PaymentInfo(bankName: 'BCA', accountNumber: '1234567890', accountHolder: 'Rina Ayu');

const _group = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  status: GroupStatus.draft,
  myRole: MemberRole.organizer,
  paymentInfo: PaymentInfo(),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;

  setUp(() => groups = FakeGroupRepository());

  Future<void> pumpPaymentInfo(WidgetTester tester, GroupDetail group) async {
    groups
      ..group = group
      ..groupResult = null;
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(PaymentInfoPage(groupId: 'g1'), container: container);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(AppTextField, label);

  testWidgets('groups the account number by 4 while typing', (tester) async {
    // Arrange
    await pumpPaymentInfo(tester, _group);

    // Act
    await tester.enterText(field('Nomor rekening'), '1234567890');
    await tester.pump();

    // Assert
    expect(find.text('1234 5678 90'), findsOneWidget);
  });

  testWidgets('a co-organizer sees the cards read-only', (tester) async {
    // Act
    await pumpPaymentInfo(tester, _group.copyWith(myRole: MemberRole.coOrganizer, paymentInfo: _info));

    // Assert
    expect(find.byType(BankAccountCard), findsOneWidget);
    expect(find.text('1234 5678 90'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Simpan'), findsNothing);
    expect(field('Nomor rekening'), findsNothing);
  });

  testWidgets('changing the account on an active group asks first', (tester) async {
    // Arrange
    await pumpPaymentInfo(tester, _group.copyWith(status: GroupStatus.active, paymentInfo: _info));
    await tester.enterText(field('Nomor rekening'), '9876543210');

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
    await tester.pumpAndSettle();

    // Assert
    expect(
      find.text('Anggota akan melihat rekening baru. Perubahan ini tercatat di aktivitas.'),
      findsOneWidget,
    );
    expect(groups.calls, isNot(contains('updatePaymentInfo')));
  });

  testWidgets('saving a draft account sends it without asking', (tester) async {
    // Arrange
    await pumpPaymentInfo(tester, _group.copyWith(paymentInfo: _info));
    await tester.enterText(field('Atas nama'), 'Rina Wulandari');

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
    await tester.pumpAndSettle();

    // Assert
    expect(groups.lastPaymentInfo?.accountHolder, 'Rina Wulandari');
    expect(groups.lastPaymentInfo?.accountNumber, '1234567890');
    expect(find.text('Rekening disimpan.'), findsOneWidget);
  });

  testWidgets('a rejected QRIS shows the error under the card', (tester) async {
    // Arrange
    await pumpPaymentInfo(tester, _group);
    groups.groupResult = const Left(
      Failure.validation(
        fieldErrors: [FieldError(field: 'file', code: 'invalid_qris', message: '')],
      ),
    );

    await tester.ensureVisible(find.bySemanticsLabel('Upload QRIS'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.bySemanticsLabel('Upload QRIS'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('QRIS tidak terbaca atau rusak. Coba gambar yang lebih jelas.'), findsOneWidget);
    expect(groups.lastQrisPath, '/tmp/photo.jpg');
  });
}
