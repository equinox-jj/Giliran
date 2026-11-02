import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/auth/presentation/sign_in/page/sign_in_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late int sent;

  setUp(() {
    repository = FakeAuthRepository()..hasSessionResult = const Right(false);
    container = authTestContainer(repository);
    sent = 0;
  });

  Future<void> pumpSignIn(WidgetTester tester, {String? initialEmail}) => tester.pumpPage(
    SignInPage(initialEmail: initialEmail, onCodeSent: () => sent++),
    container: container,
  );

  testWidgets('shows the headline and prefills the email', (tester) async {
    // Arrange
    const email = 'rina@gmail.com';

    // Act
    await pumpSignIn(tester, initialEmail: email);

    // Assert
    expect(find.text('Masuk dengan email'), findsOneWidget);
    expect(find.text(email), findsOneWidget);
  });

  testWidgets('a malformed email shows the format error and sends nothing', (tester) async {
    // Arrange
    await pumpSignIn(tester);
    await tester.enterText(find.byType(TextField), 'rina@');

    // Act
    await tester.tap(find.text('Kirim kode'));
    await tester.pump();

    // Assert
    expect(find.text(EmailField.formatError), findsOneWidget);
    expect(repository.calls, isNot(contains('requestEmailOtp')));
    expect(sent, 0);
  });

  testWidgets('sends the code for the normalized email and moves on', (tester) async {
    // Arrange
    await pumpSignIn(tester);
    await tester.enterText(find.byType(TextField), ' Rina@Gmail.com ');

    // Act
    await tester.tap(find.text('Kirim kode'));
    await tester.pumpAndSettle();

    // Assert
    expect(repository.calls, contains('requestEmailOtp'));
    expect(repository.savedPending?.email, 'rina@gmail.com');
    expect(sent, 1);
  });

  testWidgets('a 429 shows the wait and turns the button off', (tester) async {
    // Arrange
    repository.challengeResult = const Left(
      Failure.tooManyRequests(retryAfter: Duration(minutes: 12)),
    );
    await pumpSignIn(tester);
    await tester.enterText(find.byType(TextField), 'rina@gmail.com');

    // Act
    await tester.tap(find.text('Kirim kode'));
    await tester.pump();
    await tester.pump();

    // Assert
    expect(find.textContaining('Terlalu sering. Coba lagi dalam'), findsOneWidget);
    final button = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Kirim kode'));
    expect(button.onPressed, isNull);
    expect(sent, 0);
  });

  testWidgets('Tidak punya email? opens the help sheet', (tester) async {
    // Arrange
    await pumpSignIn(tester);

    // Act
    await tester.tap(find.text('Tidak punya email?'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Mengerti'), findsOneWidget);
  });
}
