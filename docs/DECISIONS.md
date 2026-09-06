# Tayo Mobile Architecture Decisions

This document records decisions that shape the current Flutter app. It is
intentionally short and should be updated when an accepted design choice
changes. Mirrors the format of `tayo-api/docs/DECISIONS.md` on the backend.

## ADR-001: Use Riverpod For State Management

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Use `flutter_riverpod` for dependency injection and state management, with
business logic living in controllers/notifiers rather than widgets.

### Rationale

Riverpod gives compile-safe DI, keeps widgets focused on presentation, and
is straightforward to unit test without a `BuildContext`.

### Consequences

Feature state (auth session, form state, loaded lists) belongs in a
provider/controller under `presentation/providers/`, not in `StatefulWidget`
fields. New features should follow the same pattern established by
`auth/presentation/providers/auth_controller.dart`.

## ADR-002: Use go_router With A Single Auth-Aware Redirect

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Use `go_router` for navigation, with one centralized `redirect` callback in
`core/routing/app_router.dart` that drives all auth-gated navigation, rather
than scattering auth checks across individual screens.

### Rationale

A single redirect function keeps the splash → login/register →
create-household → home flow legible in one place and prevents each screen
from re-implementing "am I allowed to be here" logic.

### Consequences

The router listens to `authControllerProvider` through a small
`ChangeNotifier` bridge (`_AuthChangeNotifier`) so Riverpod state changes
trigger `go_router` re-evaluation. Any new auth-dependent state (e.g. "has
the user completed onboarding") should extend this same redirect function
rather than adding a second guard mechanism.

## ADR-003: Use Dio With A Centralized 401 Interceptor

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Wrap all HTTP calls in a single `ApiClient` (`core/networking/api_client.dart`)
built on `dio`, with interceptors that inject the bearer token on every
request and normalize failures into a typed `ApiException`.

### Rationale

Centralizing token injection and error mapping means feature repositories
never touch raw HTTP or parse Laravel's validation error shape themselves.
A 401 response is also detected in one place, so session teardown doesn't
need to be duplicated at every call site.

### Consequences

`ApiClient.onUnauthorized` is the single hook for clearing session state on
token expiry/revocation. New repositories should call through `ApiClient`
rather than constructing their own `Dio` instance. `ApiException` already
carries the parsed `message` and field `errors` matching Laravel's 422
shape (see `tayo-api` ADR-001).

## ADR-004: Store Auth Tokens With flutter_secure_storage

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Persist the Sanctum bearer token on-device using `flutter_secure_storage`
(`core/storage/secure_token_storage.dart`) — Keychain on iOS,
EncryptedSharedPreferences on Android.

### Rationale

The token is a long-lived credential; platform-secure storage is the
minimum bar for handling it, matching the mobile-side half of `tayo-api`
ADR-005.

### Consequences

No other part of the app should read/write the token directly — go through
`SecureTokenStorage` so the storage mechanism can change without touching
call sites.

## ADR-005: Configure The API Base URL Via --dart-define, Not A .env File

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Read the backend URL from a compile-time `String.fromEnvironment` in
`core/config/env.dart`, defaulting to `http://127.0.0.1:8000/api/v1` and
overridden per-run with `--dart-define=API_BASE_URL=...`.

### Rationale

`--dart-define` is baked in at build time with no extra package or runtime
file I/O, and avoids accidentally shipping a `.env` file inside a release
build. The default assumes a local Laravel dev server.

### Consequences

Anyone running against an Android emulator must override with
`http://10.0.2.2:8000/api/v1` instead of the `127.0.0.1` default, since the
emulator's loopback interface doesn't reach the host machine. This is
documented inline in `env.dart` and in `ARCHITECTURE.md`'s Flutter setup
section — don't remove that comment, it's the answer to a recurring
"why can't the app reach my API" question.

## ADR-006: Hand-Written JSON Models, No Codegen Yet

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Write `fromJson`/`toJson` by hand on plain Dart classes instead of adopting
`freezed`/`json_serializable` and the `build_runner` step they require.

### Rationale

The model set is still small (`AppUser`, `Household`, `Member`). The
build_runner watch/generate cycle is a real development-loop cost that
isn't worth paying yet.

### Consequences

Revisit this once the model count or nested-JSON complexity grows enough
that hand-written parsing becomes error-prone or repetitive — likely around
Phase 3+ (Calendar) per `ROADMAP.md`, when richer nested resources
(participants, recurrence rules) start showing up.

## ADR-007: Feature-Oriented Layering (data / domain / presentation)

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

Organize `lib/features/<feature>/` into `data/` (repository talking to
`ApiClient`), `domain/` (plain entities), and
`presentation/{screens,providers}/`. Shared entities used by multiple
features (`Household`, `Member`) live in the owning feature's `domain/` and
are imported by others rather than duplicated.

### Rationale

Keeps each feature's HTTP/parsing concerns, business entities, and UI
separated and independently testable, without introducing a heavier
Domain/Application/Infrastructure split the app doesn't need yet (mirrors
`tayo-api` ADR-002's "don't over-layer before the domain earns it").

### Consequences

New features (`calendar`, `requests`, `meals`, ...) should follow the same
three-folder shape. If a feature's domain logic grows complex enough to
need its own sub-layers, revisit then — don't pre-build the structure.

## ADR-008: Backend Is The Source Of Truth For Authorization

- **Status:** Accepted
- **Date:** 2026-08-30

### Decision

The Flutter app may hide/disable UI based on role (e.g. non-owners don't
see a "delete household" button), but never treats a client-side role
check as the actual authorization boundary.

### Rationale

Matches `tayo-api` ADR-003/ADR-004: `HouseholdPolicy` on the backend is the
only place a permission decision is actually enforced. UI-level hiding is a
UX convenience, not a security control.

### Consequences

Every write path must handle a 403 from the API gracefully (surfaced via
`ApiException`), since the backend can reject an action the UI optimistically
allowed to be attempted — e.g. a stale cached role after a household admin
changes someone's permissions mid-session.
