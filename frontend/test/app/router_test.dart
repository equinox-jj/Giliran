import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/app/app.dart';
import 'package:giliran/app/deep_link_controller.dart';
import 'package:giliran/app/router.dart';
import 'package:giliran/app/routes.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/core/services/share_service.dart';
import 'package:giliran/core/storage/preferences.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/auth/presentation/pin_lock/page/pin_lock_page.dart';
import 'package:giliran/features/auth/presentation/sign_in/page/sign_in_page.dart';
import 'package:giliran/features/auth/presentation/splash/page/splash_page.dart';
import 'package:giliran/features/auth/presentation/welcome/page/welcome_page.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/presentation/groups/page/groups_page.dart';
import 'package:giliran/features/home/presentation/home/page/home_page.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/presentation/join/page/join_page.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/profile/page/profile_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_connectivity.dart';
import '../helpers/fake_group_repository.dart';
import '../helpers/fake_member_repository.dart';
import '../helpers/fake_preferences.dart';
import '../helpers/fake_share_service.dart';

void main() {
  late FakeAuthRepository repository;
  late FakePreferences preferences;
  late FakeShareService share;
  late ProviderContainer container;

  setUp(() {
    // Signed out by default.
    repository = FakeAuthRepository()..hasSessionResult = const Right(false);
    preferences = FakePreferences();
    share = FakeShareService();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        preferencesProvider.overrideWithValue(preferences),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
        shareServiceProvider.overrideWithValue(share),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(true)),
      ],
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

  Future<void> unlock(WidgetTester tester) async {
    container.read(authSessionControllerProvider.notifier).unlock();
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
      // "Lewati" is on the phone layout only; the default surface is wide.
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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

  group('deep links', () {
    testWidgets('pending invite resumes after sign-in', (tester) async {
      // Arrange
      await pumpRouterApp(tester);
      await go(tester, '/j/K7P2QX9M');
      final welcomeShown = find.byType(WelcomePage).evaluate().isNotEmpty;
      final bannerShown = find.text('Kamu diundang ke grup arisan. Masuk dulu untuk gabung.').evaluate().isNotEmpty;

      // Act
      signIn();
      container.invalidate(authSessionControllerProvider);
      await tester.pumpAndSettle();
      await unlock(tester);

      // Assert
      expect(welcomeShown, isTrue);
      expect(bannerShown, isTrue);
      expect(find.byType(JoinPage), findsOneWidget);
      expect(container.read(deepLinkControllerProvider).pending, isNull);
      expect(preferences.pendingDeepLink, isNull);
    });

    testWidgets('a signed-out invite link is stored for the next start', (tester) async {
      // Arrange
      await pumpRouterApp(tester);

      // Act
      await go(tester, '/j/K7P2QX9M');

      // Assert
      expect(preferences.pendingDeepLink, '/j/K7P2QX9M');
    });

    testWidgets('a full https invite link is stored as its in-app path', (tester) async {
      // Arrange
      await pumpRouterApp(tester);

      // Act
      await go(tester, 'https://giliran.monai.my.id/j/K7P2QX9M');

      // Assert
      expect(preferences.pendingDeepLink, '/j/K7P2QX9M');
      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testWidgets('a verification link opens the public page in the browser', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);
      await unlock(tester);

      // Act
      await go(tester, '/v/7H2K9QX4MP');

      // Assert
      expect(share.openedUrls.single.toString(), 'https://giliran.monai.my.id/v/7H2K9QX4MP');
      expect(find.byType(HomePage), findsOneWidget);
    });
  });

  group('signed in', () {
    testWidgets('the splash leaves for the lock, and unlocking opens Home', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);
      final lockShown = find.byType(PinLockPage).evaluate().isNotEmpty;

      // Act
      await unlock(tester);

      // Assert
      expect(lockShown, isTrue);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(AppNavShell), findsOneWidget);
    });

    testWidgets('tapping the Grup tab switches branch', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);
      await unlock(tester);

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
      await unlock(tester);

      // Act
      await go(tester, const ProfileRoute().location);
      final profileShown = find.byType(ProfilePage).evaluate().isNotEmpty;
      await go(tester, const SignInRoute().location);

      // Assert
      expect(profileShown, isTrue);
      expect(find.byType(SignInPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('locking again covers the open tab, and unlocking returns to it', (tester) async {
      // Arrange
      signIn();
      await pumpRouterApp(tester);
      await unlock(tester);
      await go(tester, const GroupsRoute().location);

      // Act
      container.read(authSessionControllerProvider.notifier).lock();
      await tester.pumpAndSettle();
      final lockShown = find.byType(PinLockPage).evaluate().isNotEmpty;
      await unlock(tester);

      // Assert
      expect(lockShown, isTrue);
      expect(find.byType(GroupsPage), findsOneWidget);
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
    final signIn = Uri.parse(const SignInRoute().location);
    final code = Uri.parse(const VerifyOtpRoute().location);
    final name = Uri.parse(const FillNameRoute().location);
    final newPin = Uri.parse(const SetPinRoute().location);
    final biometric = Uri.parse(const BiometricRoute().location);
    final lock = Uri.parse(const LockRoute().location);
    final forgotPin = Uri.parse(const ForgotPinRoute().location);
    final splash = const SplashRoute().location;

    test('holds protected routes on the splash while loading', () {
      // Arrange
      const status = AsyncLoading<AuthStatus>();

      // Act
      final onHome = authRedirect(status, home);
      final onWelcome = authRedirect(status, welcome);
      final onCode = authRedirect(status, code);

      // Assert
      expect(onHome, splash);
      expect(onWelcome, isNull);
      expect(onCode, isNull);
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

    test('keeps a signed-out user on Welcome, sign-in, code and forgot PIN', () {
      // Arrange
      const statuses = [
        AsyncData<AuthStatus>(AuthStatus.signedOut()),
        AsyncError<AuthStatus>(Failure.cache(), StackTrace.empty),
      ];

      // Act
      final targets = [
        for (final s in statuses) ...[
          authRedirect(s, home),
          authRedirect(s, lock),
          authRedirect(s, signIn),
          authRedirect(s, code),
          authRedirect(s, forgotPin),
        ],
      ];

      // Assert
      final w = const WelcomeRoute().location;
      expect(targets, [w, w, null, null, null, w, w, null, null, null]);
    });

    test('resumes an open code request on the code screen', () {
      // Arrange
      const status = AsyncData<AuthStatus>(AuthStatus.otpPending());

      // Act
      final fromHome = authRedirect(status, home);
      final fromWelcome = authRedirect(status, welcome);
      final onSignIn = authRedirect(status, signIn);
      final onCode = authRedirect(status, code);

      // Assert
      expect(fromHome, code.path);
      expect(fromWelcome, code.path);
      expect(onSignIn, isNull);
      expect(onCode, isNull);
    });

    test('sends onboarding statuses to their step only', () {
      // Arrange
      const needsName = AsyncData<AuthStatus>(AuthStatus.needsName());
      const needsPin = AsyncData<AuthStatus>(AuthStatus.needsPin());

      // Act
      final nameFromHome = authRedirect(needsName, home);
      final nameOnName = authRedirect(needsName, name);
      final pinFromName = authRedirect(needsPin, name);
      final pinOnPin = authRedirect(needsPin, newPin);

      // Assert
      expect(nameFromHome, name.path);
      expect(nameOnName, isNull);
      expect(pinFromName, newPin.path);
      expect(pinOnPin, isNull);
    });

    test('a locked session reaches only the lock and forgot PIN', () {
      // Arrange
      const status = AsyncData<AuthStatus>(AuthStatus.locked());

      // Act
      final fromHome = authRedirect(status, home);
      final fromWelcome = authRedirect(status, welcome);
      final onLock = authRedirect(status, lock);
      final onForgot = authRedirect(status, forgotPin);

      // Assert
      expect(fromHome, const LockRoute(from: '/home').location);
      expect(fromWelcome, lock.path);
      expect(onLock, isNull);
      expect(onForgot, isNull);
    });

    test('the lock keeps the covered location, query included', () {
      // Arrange
      const status = AsyncData<AuthStatus>(AuthStatus.locked());
      final covered = Uri.parse('/profile/security/pin?tab=2');

      // Act
      final target = authRedirect(status, covered);

      // Assert
      expect(target, const LockRoute(from: '/profile/security/pin?tab=2').location);
      expect(Uri.parse(target!).queryParameters['from'], covered.toString());
    });

    test('unlocking returns to the covered location', () {
      // Arrange
      const status = AsyncData<AuthStatus>(AuthStatus.unlocked());
      final onLock = Uri.parse(const LockRoute(from: '/groups').location);

      // Act
      final target = authRedirect(status, onLock);

      // Assert
      expect(target, '/groups');
    });

    test('an unlocked user leaves sign-in steps for the biometric offer', () {
      // Arrange
      const status = AsyncData<AuthStatus>(AuthStatus.unlocked());

      // Act
      final fromSteps = [
        for (final uri in [code, name, newPin, forgotPin]) authRedirect(status, uri),
      ];
      final onBiometric = authRedirect(status, biometric);

      // Assert
      expect(fromSteps, everyElement(biometric.path));
      expect(onBiometric, isNull);
    });

    test('an unlocked user skips Welcome, sign-in and the lock for Home', () {
      // Arrange
      const status = AsyncData<AuthStatus>(AuthStatus.unlocked());

      // Act
      final targets = [
        for (final uri in [welcome, signIn, lock]) authRedirect(status, uri),
      ];
      final onHome = authRedirect(status, home);

      // Assert
      expect(targets, everyElement(const HomeRoute().location));
      expect(onHome, isNull);
    });
    test('sends a signed-out invite link to Welcome', () {
      // Act
      final target = authRedirect(const AsyncData(AuthSignedOut()), Uri.parse('/j/K7P2QX9M'));

      // Assert
      expect(target, const WelcomeRoute(invited: true).location);
    });

    test('an unlocked session goes to the pending link instead of Home', () {
      // Act
      final target = authRedirect(const AsyncData(AuthUnlocked()), home, pending: '/j/K7P2QX9M');

      // Assert
      expect(target, '/j/K7P2QX9M');
    });

    test('the biometric opt-in comes before the pending link', () {
      // Act
      final target = authRedirect(const AsyncData(AuthUnlocked()), biometric, pending: '/j/K7P2QX9M');

      // Assert
      expect(target, isNull);
    });
  });

  group('lockReturnTo', () {
    test('returns an app path with its query', () {
      // Arrange
      const from = '/profile/security/email?step=2';

      // Act
      final target = lockReturnTo(from);

      // Assert
      expect(target, from);
    });

    test('falls back to Home for nothing, outside URLs and the lock itself', () {
      // Arrange
      const unsafe = [
        null,
        'https://example.com/home',
        '//example.com/home',
        'home',
        '/lock',
        '/lock?from=%2Fgroups',
      ];

      // Act
      final targets = [for (final from in unsafe) lockReturnTo(from)];

      // Assert
      expect(targets, everyElement(const HomeRoute().location));
    });
  });
}
