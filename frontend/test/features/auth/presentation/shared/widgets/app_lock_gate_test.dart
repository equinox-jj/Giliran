import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/auth/presentation/shared/widgets/app_lock_gate.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    repository = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Ana', pinSet: true));
    container = authTestContainer(repository);
    now = DateTime(2026, 11, 2, 9);
  });

  Future<void> pumpGate(WidgetTester tester, {bool unlocked = true}) async {
    await container.read(authSessionControllerProvider.future);
    if (unlocked) container.read(authSessionControllerProvider.notifier).unlock();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AppLockGate(now: () => now, child: const Text('Saldo Rp200.000')),
        ),
      ),
    );
  }

  Future<void> setLifecycle(WidgetTester tester, List<AppLifecycleState> states) async {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  const leave = [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused];
  const comeBack = [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed];

  AuthStatus? status() => container.read(authSessionControllerProvider).value;

  tearDown(() => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  testWidgets('covers an open session when the app goes inactive', (tester) async {
    // Arrange
    await pumpGate(tester);

    // Act
    await setLifecycle(tester, [AppLifecycleState.inactive]);

    // Assert
    expect(find.byType(Illustration), findsOneWidget);
  });

  testWidgets('does not cover the lock screen', (tester) async {
    // Arrange
    await pumpGate(tester, unlocked: false);

    // Act
    await setLifecycle(tester, [AppLifecycleState.inactive]);

    // Assert
    expect(find.byType(Illustration), findsNothing);
  });

  testWidgets('uncovers and stays open after a short time away', (tester) async {
    // Arrange
    await pumpGate(tester);
    await setLifecycle(tester, leave);

    // Act
    now = now.add(const Duration(minutes: 4));
    await setLifecycle(tester, comeBack);
    await tester.pump();

    // Assert
    expect(find.byType(Illustration), findsNothing);
    expect(status(), isA<AuthUnlocked>());
  });

  testWidgets('locks after five minutes in the background', (tester) async {
    // Arrange
    await pumpGate(tester);
    await setLifecycle(tester, leave);

    // Act
    now = now.add(const Duration(minutes: 5));
    await setLifecycle(tester, comeBack);
    await tester.pump();

    // Assert
    expect(status(), isA<AuthLocked>());
  });

  testWidgets('a brief inactive (system dialog) never locks', (tester) async {
    // Arrange
    await pumpGate(tester);
    await setLifecycle(tester, [AppLifecycleState.inactive]);

    // Act
    now = now.add(const Duration(minutes: 10));
    await setLifecycle(tester, [AppLifecycleState.resumed]);
    await tester.pump();

    // Assert
    expect(status(), isA<AuthUnlocked>());
    expect(find.byType(Illustration), findsNothing);
  });
}
