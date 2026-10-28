import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/app.dart';
import 'package:giliran/app/router.dart';
import 'package:giliran/app/routes.dart';
import 'package:giliran/features/auth/presentation/pages/sign_in_page.dart';
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
    await tester.pumpAndSettle();
  }

  testWidgets('starts on Home inside the nav shell', (tester) async {
    await pumpRouterApp(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppNavShell), findsOneWidget);
  });

  testWidgets('tapping the Grup tab switches branch', (tester) async {
    await pumpRouterApp(tester);
    await tester.tap(find.text('Grup').last);
    await tester.pumpAndSettle();
    expect(find.byType(GroupsPage), findsOneWidget);
    expect(find.byType(AppNavShell), findsOneWidget);
  });

  testWidgets('deep links to tab and top-level routes', (tester) async {
    await pumpRouterApp(tester);
    final router = container.read(routerProvider);

    router.go(const ProfileRoute().location);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    router.go(const SignInRoute().location);
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(AppNavShell), findsNothing);
  });
}
