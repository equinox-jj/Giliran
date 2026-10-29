import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/app.dart';
import 'package:giliran/app/router.dart';
import 'package:giliran/app/routes.dart';
import 'package:giliran/features/auth/presentation/pages/sign_in_page.dart';
import 'package:giliran/features/auth/presentation/pages/splash_page.dart';
import 'package:giliran/features/auth/presentation/pages/welcome_page.dart';
import 'package:giliran/features/group/presentation/pages/groups_page.dart';
import 'package:giliran/features/home/presentation/pages/home_page.dart';
import 'package:giliran/features/profile/presentation/pages/profile_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpRouterApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GiliranApp(),
      ),
    );
    // Let the splash hold run out so no timer is left pending.
    await tester.pump(SplashPage.minHold);
    await tester.pumpAndSettle();
  }

  Future<void> goHome(WidgetTester tester) async {
    container.read(routerProvider).go(const HomeRoute().location);
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the splash, then shows Welcome', (tester) async {
    // Arrange
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GiliranApp(),
      ),
    );
    await tester.pump();
    final splashShown = find.byType(SplashPage).evaluate().isNotEmpty;

    // Act
    await tester.pump(SplashPage.minHold);
    await tester.pumpAndSettle();

    // Assert
    expect(splashShown, isTrue);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.byType(AppNavShell), findsNothing);
  });

  testWidgets('Masuk dengan email opens sign-in from Welcome', (tester) async {
    // Arrange
    await pumpRouterApp(tester);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('Masuk dengan email'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('Home sits inside the nav shell', (tester) async {
    // Arrange
    await pumpRouterApp(tester);

    // Act
    await goHome(tester);

    // Assert
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppNavShell), findsOneWidget);
  });

  testWidgets('tapping the Grup tab switches branch', (tester) async {
    // Arrange
    await pumpRouterApp(tester);
    await goHome(tester);

    // Act
    await tester.tap(find.text('Grup').last);
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(GroupsPage), findsOneWidget);
    expect(find.byType(AppNavShell), findsOneWidget);
  });

  testWidgets('deep links to tab and top-level routes', (tester) async {
    // Arrange
    await pumpRouterApp(tester);
    final router = container.read(routerProvider);

    // Act
    router.go(const ProfileRoute().location);
    await tester.pumpAndSettle();
    final profileShown = find.byType(ProfilePage).evaluate().isNotEmpty;
    router.go(const SignInRoute().location);
    await tester.pumpAndSettle();

    // Assert
    expect(profileShown, isTrue);
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(AppNavShell), findsNothing);
  });
}
