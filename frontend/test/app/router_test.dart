import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/app/app.dart';
import 'package:giliran/app/router.dart';
import 'package:giliran/app/routes.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/auth/presentation/sign_in/page/sign_in_page.dart';
import 'package:giliran/features/auth/presentation/splash/page/splash_page.dart';
import 'package:giliran/features/auth/presentation/welcome/page/welcome_page.dart';
import 'package:giliran/features/group/presentation/pages/groups_page.dart';
import 'package:giliran/features/home/presentation/pages/home_page.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/pages/profile_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';

import '../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    // Signed out by default.
    repository = FakeAuthRepository()..hasSessionResult = const Right(false);
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() => container.dispose());

  void signIn() {
    repository
      ..hasSessionResult = const Right(true)
      ..userResult = Right(ProfileData(name: 'Ana', pinSet: true));
  }

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

  Future<void> go(WidgetTester tester, String location) async {
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  group('signed out', () {
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

    testWidgets('a tab deep link redirects to Welcome', (tester) async {
      // Arrange
      await pumpRouterApp(tester);

      // Act
      await go(tester, const ProfileRoute().location);

      // Assert
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);
    });
  });

  group('signed in', () {
    testWidgets('the splash leaves for Home inside the nav shell', (tester) async {
      // Arrange
      signIn();

      // Act
      await pumpRouterApp(tester);

      // Assert
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(AppNavShell), findsOneWidget);
    });

    testWidgets('tapping the Grup tab switches branch', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);

      // Act
      await tester.tap(find.text('Grup').last);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(GroupsPage), findsOneWidget);
      expect(find.byType(AppNavShell), findsOneWidget);
    });

    testWidgets('deep links to a tab, and sign-in sends back Home', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);

      // Act
      await go(tester, const ProfileRoute().location);
      final profileShown = find.byType(ProfilePage).evaluate().isNotEmpty;
      await go(tester, const SignInRoute().location);

      // Assert
      expect(profileShown, isTrue);
      expect(find.byType(SignInPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('logging out returns to Welcome', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);

      // Act
      await container.read(authSessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  });

  group('authRedirect', () {
    final home = Uri.parse(const HomeRoute().location);
    final welcome = Uri.parse(const WelcomeRoute().location);
    final splash = const SplashRoute().location;

    test('holds protected routes on the splash while loading', () {
      // Arrange
      const status = AsyncLoading<AuthStatus>();

      // Act
      final onHome = authRedirect(status, home);
      final onWelcome = authRedirect(status, welcome);

      // Assert
      expect(onHome, splash);
      expect(onWelcome, isNull);
    });

    test('never redirects the splash or the gallery', () {
      // Arrange
      const status = AsyncData(AuthStatus.signedOut());

      // Act
      final onSplash = authRedirect(status, Uri.parse(splash));
      final onGallery = authRedirect(
        status,
        Uri.parse(const GalleryRoute().location),
      );

      // Assert
      expect(onSplash, isNull);
      expect(onGallery, isNull);
    });

    test('sends every unfinished status to Welcome', () {
      // Arrange
      const statuses = [
        AsyncData<AuthStatus>(AuthStatus.signedOut()),
        AsyncData<AuthStatus>(AuthStatus.otpPending()),
        AsyncData<AuthStatus>(AuthStatus.needsName()),
        AsyncData<AuthStatus>(AuthStatus.needsPin()),
        AsyncError<AuthStatus>(Failure.cache(), StackTrace.empty),
      ];

      // Act
      final targets = [for (final s in statuses) authRedirect(s, home)];

      // Assert
      expect(targets, everyElement(const WelcomeRoute().location));
    });

    test('sends a signed-in user from Welcome to Home', () {
      // Arrange
      const locked = AsyncData<AuthStatus>(AuthStatus.locked());
      const unlocked = AsyncData<AuthStatus>(AuthStatus.unlocked());

      // Act
      final fromWelcome = authRedirect(locked, welcome);
      final onHome = authRedirect(unlocked, home);

      // Assert
      expect(fromWelcome, const HomeRoute().location);
      expect(onHome, isNull);
    });
  });
}
