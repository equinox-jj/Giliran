import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/features/auth/presentation/set_pin/page/set_pin_page.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Rina', pinSet: false));
    container = authTestContainer(repository);
  });

  Future<void> pumpSetPin(WidgetTester tester) => tester.pumpPage(const SetPinPage(), container: container);

  testWidgets('asks for the PIN, then for it again', (tester) async {
    // Arrange
    await pumpSetPin(tester);
    final firstStep = find.text('Buat PIN 6 digit').evaluate().isNotEmpty;

    // Act
    await tester.enterPin('135790');
    await tester.pump();

    // Assert
    expect(firstStep, isTrue);
    expect(find.text('Ulangi PIN'), findsOneWidget);
    expect(repository.calls, isNot(contains('setPin')));
  });

  testWidgets('sets the PIN on the second entry', (tester) async {
    // Arrange
    await pumpSetPin(tester);
    await tester.enterPin('135790');

    // Act
    await tester.enterPin('135790');
    await tester.pump();

    // Assert
    expect(repository.calls, contains('setPin'));
    expect(repository.savedUser?.pinSet, isTrue);
  });

  testWidgets('a weak PIN starts over with the reason', (tester) async {
    // Arrange
    repository.unitResult = const Left(
      Failure.validation(
        fieldErrors: [FieldError(field: 'pin', code: 'pin_too_weak', message: 'Lemah')],
      ),
    );
    await pumpSetPin(tester);
    await tester.enterPin('123456');

    // Act
    await tester.enterPin('123456');
    await tester.pump();

    // Assert
    expect(find.text('Hindari angka berurutan atau sama semua.'), findsOneWidget);
    expect(find.text('Buat PIN 6 digit'), findsOneWidget);
  });

  testWidgets('back on the second step starts over', (tester) async {
    // Arrange
    await pumpSetPin(tester);
    await tester.enterPin('135790');

    // Act
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pump();

    // Assert
    expect(find.text('Buat PIN 6 digit'), findsOneWidget);
  });

  group('fits the screen', () {
    const screens = {
      'small phone': Size(320, 568),
      'phone': Size(390, 844),
      'small phone landscape': Size(568, 320),
      'phone landscape': Size(844, 390),
      'tablet': Size(820, 1180),
      'tablet landscape': Size(1180, 820),
    };
    // Below the 360 dp floor the pad scrolls instead of shrinking its keys
    // under the tap minimum: there, each part only has to scroll into view.
    const scrolls = {'small phone', 'small phone landscape'};
    for (final MapEntry(key: name, value: size) in screens.entries) {
      testWidgets('on a $name', (tester) async {
        // Arrange
        await tester.pumpPage(const SetPinPage(), container: container, size: size);
        final keypad = find.bySemanticsLabel('Hapus');
        final hint = find.textContaining('Hindari angka');

        // Act
        if (scrolls.contains(name)) await tester.ensureVisible(keypad);
        final keypadBottom = tester.getBottomLeft(keypad).dy;
        if (scrolls.contains(name)) await tester.ensureVisible(hint);
        final hintBottom = tester.getBottomLeft(hint).dy;

        // Assert
        expect(tester.takeException(), isNull);
        expect(keypadBottom, lessThanOrEqualTo(size.height));
        expect(hintBottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}
