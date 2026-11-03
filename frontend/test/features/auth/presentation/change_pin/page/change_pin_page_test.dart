import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/presentation/change_pin/page/change_pin_page.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late int doneCalls;
  late int forgotCalls;

  setUp(() {
    repository = FakeAuthRepository();
    container = authTestContainer(repository);
    doneCalls = 0;
    forgotCalls = 0;
  });

  Future<void> pumpChangePin(WidgetTester tester) => tester.pumpPage(
    ChangePinPage(onDone: () => doneCalls++, onForgotPin: () => forgotCalls++),
    container: container,
  );

  Future<void> enterAll(WidgetTester tester) async {
    await tester.enterPin('111111');
    await tester.enterPin('246802');
    await tester.enterPin('246802');
    await tester.pump();
  }

  testWidgets('asks for the current PIN, the new PIN, then the new PIN again', (tester) async {
    // Arrange
    await pumpChangePin(tester);
    final first = find.text('Masukkan PIN lama').evaluate().isNotEmpty;

    // Act
    await tester.enterPin('111111');
    final second = find.text('Buat PIN baru').evaluate().isNotEmpty;
    await tester.enterPin('246802');

    // Assert
    expect(first, isTrue);
    expect(second, isTrue);
    expect(find.text('Ulangi PIN baru'), findsOneWidget);
    expect(find.text('Langkah 3 dari 3'), findsOneWidget);
  });

  testWidgets('changes the PIN, shows the toast and closes', (tester) async {
    // Arrange
    await pumpChangePin(tester);

    // Act
    await enterAll(tester);

    // Assert
    expect(repository.lastArgs, ('111111', '246802', '246802'));
    expect(find.text('PIN berhasil diganti.'), findsOneWidget);
    expect(doneCalls, 1);
  });

  testWidgets('a wrong current PIN returns to step 1 with the attempts left', (tester) async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinInvalid,
        status: 401,
        extensions: {'attempts_remaining': 2},
      ),
    );
    await pumpChangePin(tester);

    // Act
    await enterAll(tester);

    // Assert
    expect(find.text('Masukkan PIN lama'), findsOneWidget);
    expect(find.text('PIN salah. Sisa 2 percobaan.'), findsOneWidget);
    expect(doneCalls, 0);
  });

  testWidgets('a locked PIN shows the countdown with Lupa PIN', (tester) async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinLocked,
        status: 423,
        retryAfter: Duration(minutes: 15),
      ),
    );
    await pumpChangePin(tester);
    await enterAll(tester);

    // Act
    await tester.tap(find.text('Lupa PIN?'));
    await tester.pump();

    // Assert
    expect(find.text('PIN terkunci sementara. Coba lagi setelah waktu habis.'), findsOneWidget);
    expect(forgotCalls, 1);
  });

  testWidgets('back on step 1 closes the flow', (tester) async {
    // Arrange
    await pumpChangePin(tester);

    // Act
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pump();

    // Assert
    expect(doneCalls, 1);
  });

  testWidgets('back on step 2 returns to the current PIN', (tester) async {
    // Arrange
    await pumpChangePin(tester);
    await tester.enterPin('111111');

    // Act
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pump();

    // Assert
    expect(find.text('Masukkan PIN lama'), findsOneWidget);
    expect(doneCalls, 0);
  });
}
