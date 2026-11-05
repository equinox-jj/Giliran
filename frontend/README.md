# Giliran app

The Flutter app for Giliran, a transparent arisan (rotating savings group) manager. It targets Android first, plus iOS, on phones and tablets. UI copy is Indonesian (`id_ID`), with an English ARB kept in step. The API it talks to is in [`../backend`](../backend).

## Stack

- Flutter (stable 3.47.x) and Dart 3.13, using the decoupled `material_ui` and `cupertino_ui` packages
- State and DI: Riverpod with code generation
- Routing: go_router with typed routes (`go_router_builder`)
- Local cache: Drift (SQLite)
- Networking: Dio, with errors returned as `Either<Failure, T>` (fpdart)
- Models: freezed and json_serializable
- Push: Firebase Messaging, with Crashlytics for crash reports
- Localization: Flutter `gen-l10n` (`lib/core/l10n/*.arb`)

## Getting started

Prerequisites: the Flutter SDK matching [`.github/workflows/frontend.yml`](../.github/workflows/frontend.yml) and a running backend (see [`../backend/README.md`](../backend/README.md)).

Firebase config is not committed. Generate it with `flutterfire configure`, which creates:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

```sh
flutter pub get                                           # also generates the l10n output
dart run build_runner build --delete-conflicting-outputs  # *.g.dart and *.freezed.dart
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

`API_BASE_URL` depends on the target:

| Target | Value |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080/api/v1` |
| iOS simulator | `http://localhost:8080/api/v1` |
| Physical device | `http://<your-LAN-IP>:8080/api/v1` |

Debug builds also expose a component gallery at `/gallery` that shows every shared widget. It redirects to Home in release builds.

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/gen/`) are gitignored. Re-run build_runner after changing a `@riverpod` provider, a typed route, or a freezed or json model.

## Common commands

```sh
flutter analyze
dart format lib test
flutter test                                         # all tests
flutter test test/shared/widgets/widgets_test.dart   # one file
flutter test --plain-name 'shows the disabled reason'
```

## Project structure

```text
lib/
├── main.dart            Firebase, Crashlytics, licenses, ProviderScope
├── app/                 App widget, router and typed routes, push and deep-link controllers, component gallery
├── core/                Cross-cutting code
│   ├── database/        Drift database and DAOs
│   ├── error/           AppException, Failure, error mapping
│   ├── l10n/            ARB files and generated localizations
│   ├── network/         Dio, endpoints, refresh interceptor
│   ├── storage/         Secure storage and shared preferences keys
│   ├── themes/          "Tikar" design tokens and ThemeExtensions
│   └── usecase/         UseCase base types
├── features/            One folder per feature, each split into data/, domain/, presentation/
│   └── auth, group, member, payment, draw, history, reminder, profile, settings, home
└── shared/widgets/      The Tikar component set
```

Features follow Clean Architecture. Datasources return models, repositories map them to entities, usecases hold the business rules, and Riverpod controllers only hold state and call usecases. Screens read from the Drift cache and refresh from the API into it.

## Tests

Tests mirror the `lib/` layout.

- `test/helpers/pump_app.dart` pumps a widget inside the themed app.
- `test/helpers/a11y.dart` checks a screen at 360 dp and 130% text against the tap target, label and contrast guidelines.
- `test/core/l10n/arb_parity_test.dart` keeps the Indonesian and English ARB files in step.
- `test/fixtures/draw_golden.json` holds the backend's draw vectors. The app recomputes `hmac-sha256-v1` on the device and must match them.

## Documentation

- [`docs/PRD.md`](docs/PRD.md): features, roles and business rules
- [`docs/DESIGN_SYSTEM_V1.md`](docs/DESIGN_SYSTEM_V1.md): tokens, principles and components
- [`docs/DESIGN_GAPS.md`](docs/DESIGN_GAPS.md): what the code still lacks against the design
- [`docs/DB_SCHEME.md`](docs/DB_SCHEME.md): data model
- [`../backend/api/api-spec.yaml`](../backend/api/api-spec.yaml): the API contract
- [`CLAUDE.md`](CLAUDE.md): coding conventions and architecture rules

## CI

[`frontend.yml`](../.github/workflows/frontend.yml) formats, analyzes and tests on every push and pull request that touches `frontend/`, and builds a signed release App Bundle on pushes to `main`. Its secrets (Firebase files and the upload keystore) are listed at the top of the workflow.
