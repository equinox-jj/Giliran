# Giliran

Giliran is a transparent arisan (rotating savings group) manager. An organizer runs a group of members who each pay a fixed share every period. The app records who paid, draws the period's winner with a verifiable commit-reveal draw, and records the payout. **It records money; it never moves it.**

This is a monorepo with two projects:

| Directory | What it is | Stack |
| --- | --- | --- |
| [`frontend/`](frontend) | Mobile app (Android first, iOS too, phone and tablet). UI copy is Indonesian. | Flutter, Riverpod, go_router, Drift |
| [`backend/`](backend) | HTTP API and background worker | Go, Fiber, PostgreSQL, MinIO, River |

## How it fits together

```mermaid
flowchart LR
    app["Flutter app<br/>(frontend)"] -- "REST /api/v1" --> api["cmd/api<br/>(backend)"]
    api --> pg[("PostgreSQL")]
    api --> minio[("MinIO<br/>avatars, proofs, QRIS")]
    worker["cmd/worker<br/>River jobs"] --> pg
    worker -- "sign-in codes" --> smtp["Email (SMTP)"]
    worker -- "push" --> fcm["FCM"]
    fcm -.-> app
```

- The app caches groups, periods, payments and activity in a local Drift database and refreshes from the API (the server wins). Offline cash marks are queued and sent when the connection returns.
- Sign-in is by emailed code, with an optional PIN.
- Each draw publishes a seed hash when the period opens and reveals the seed at the draw, so anyone can recompute the winner. The app re-checks the draw on the device, and a public page at `/v/{code}` lets anyone verify it.

## Screenshots

| Launch | Onboarding 2 | Onboarding 3 | Login |
| --- | --- | --- | --- |
| <img src="screenshots/01-launch.png" width="200" alt="Launch"> | <img src="screenshots/02-onboarding-2.png" width="200" alt="Onboarding 2"> | <img src="screenshots/03-onboarding-3.png" width="200" alt="Onboarding 3"> | <img src="screenshots/04-login.png" width="200" alt="Login"> |

| Sign-in code | Profile setup | PIN | Home (empty) |
| --- | --- | --- | --- |
| <img src="screenshots/05-otp.png" width="200" alt="Sign-in code"> | <img src="screenshots/06-profile.png" width="200" alt="Profile setup"> | <img src="screenshots/07-pin.png" width="200" alt="PIN"> | <img src="screenshots/08-home-empty.png" width="200" alt="Home, empty"> |

| Create group 1 | Create group 2 | Group detail | Home |
| --- | --- | --- | --- |
| <img src="screenshots/09-create-group-1.png" width="200" alt="Create group, step 1"> | <img src="screenshots/10-create-group-2.png" width="200" alt="Create group, step 2"> | <img src="screenshots/11-group-detail.png" width="200" alt="Group detail"> | <img src="screenshots/12-home.png" width="200" alt="Home"> |

| Activity | Profile |
| --- | --- |
| <img src="screenshots/13-activity.png" width="200" alt="Activity"> | <img src="screenshots/14-profile.png" width="200" alt="Profile"> |

## Quick start

Run the backend, then point the app at it.

```sh
# 1. Backend (needs Go, Docker; see backend/README.md for the full list)
cd backend
cp .env.example .env        # fill in JWT_SECRET, OTP_SECRET and the CHANGE_ME values
make up                     # Postgres, MinIO, Mailpit, migrations, API and worker
curl localhost:8080/api/v1/health

# 2. App (needs Flutter and a Firebase config; see frontend/README.md)
cd ../frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1   # Android emulator
```

In development the worker sends every email to Mailpit at <http://localhost:8025>, which is where sign-in codes show up.

## Documentation

| Topic | Where |
| --- | --- |
| Product requirements | [`backend/docs/PRD.md`](backend/docs/PRD.md), [`frontend/docs/PRD.md`](frontend/docs/PRD.md) |
| Database schema, state machines, draw algorithm | [`backend/docs/DB_SCHEME.md`](backend/docs/DB_SCHEME.md) |
| API contract (OpenAPI 3.1) | [`backend/api/api-spec.yaml`](backend/api/api-spec.yaml) |
| Design system ("Tikar") | [`frontend/docs/DESIGN_SYSTEM_V1.md`](frontend/docs/DESIGN_SYSTEM_V1.md) |
| Backend setup, config, tests, deploy | [`backend/README.md`](backend/README.md) |
| Frontend setup, structure, tests | [`frontend/README.md`](frontend/README.md) |

## CI

GitHub Actions in [`.github/workflows`](.github/workflows):

- `backend.yml`: lint, `sqlc diff`, unit and integration tests, and image builds.
- `frontend.yml`: format, analyze and test, plus a signed release App Bundle on pushes to `main`.

## Contributing notes

Each project has a `CLAUDE.md` with its conventions ([backend](backend/CLAUDE.md), [frontend](frontend/CLAUDE.md)). Generated Dart files (`*.g.dart`, `*.freezed.dart`, l10n output) and secrets (`.env`, Firebase config, keystores) are gitignored and must not be committed.
