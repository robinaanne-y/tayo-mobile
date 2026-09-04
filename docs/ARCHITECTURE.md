# Family Management App — Architecture

## 1. Architecture Overview

The application is a mobile-first family coordination platform.

Recommended architecture:

```text
┌──────────────────────────────┐
│          Flutter             │
│       iOS + Android          │
└──────────────┬───────────────┘
               │
          HTTPS / JSON
               │
               ▼
┌──────────────────────────────┐
│          Laravel             │
│          REST API            │
│                              │
│ Domain / Application Logic   │
│ Authentication               │
│ Authorization                │
│ Notifications                │
│ Jobs / Scheduling             │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         PostgreSQL           │
│        Primary Database      │
└──────────────────────────────┘

Supporting services introduced as needed:

Laravel Reverb → Realtime WebSockets
Firebase FCM  → Push notifications
Amazon S3     → File storage
Maps provider → Maps/location
RevenueCat    → Mobile subscriptions
PostHog/Firebase Analytics → Product analytics
```

---

# 2. Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Mobile | **Flutter / Dart** | iOS and Android application |
| Backend | **Laravel / PHP** | REST API and business logic |
| Database | **PostgreSQL** | Relational application data |
| Authentication | **Laravel Sanctum** initially | API authentication |
| Authorization | Laravel Policies/Gates | Role and resource permissions |
| Realtime | **Laravel Reverb** | WebSocket updates |
| Push | **Firebase Cloud Messaging** | Mobile notifications |
| File Storage | **Amazon S3** | Images and future attachments |
| Maps | **Google Maps or Mapbox** | Family map and event locations |
| Subscriptions | **RevenueCat** | App Store / Google Play subscriptions |
| Analytics | **PostHog or Firebase Analytics** | Product usage analytics |
| CI/CD | **GitHub Actions** | Automated testing/build/deployment |
| Hosting | **AWS / Forge-managed infrastructure** | Backend hosting |

The exact infrastructure provider can change without changing the domain architecture.

---

# 3. Architectural Principles

## 3.1 Mobile-first

Flutter is the primary client.

The backend must not assume that the client is always online.

Important mobile considerations:

- Loading states
- Network failure handling
- Retry behavior
- Local caching where useful
- Push notification deep links
- Background restrictions
- Secure local token storage

## 3.2 API-first

The Laravel application exposes versioned APIs.

Example:

```text
/api/v1/auth/...
/api/v1/households/...
/api/v1/members/...
/api/v1/events/...
/api/v1/meals/...
/api/v1/groceries/...
```

The Flutter application should not access the database directly.

## 3.3 Modular monolith

Laravel should begin as one deployable application with clearly separated domain modules.

Possible structure:

```text
app/
├── Domain/
│   ├── Users/
│   ├── Households/
│   ├── Members/
│   ├── Events/
│   ├── Requests/
│   ├── Meals/
│   ├── Groceries/
│   ├── Tasks/
│   ├── Trips/
│   ├── Locations/
│   └── Notifications/
│
├── Application/
│   ├── ...
│
└── Infrastructure/
    ├── ...
```

The exact folder organization may follow Laravel conventions, but domain boundaries should remain clear.

Do not split these modules into microservices unless scale or operational requirements justify it.

> **Foundation note:** the current codebase follows standard Laravel
> conventions (`app/Models`, `app/Http/Controllers/Api/V1`, `app/Policies`,
> `app/Enums`) rather than the `Domain/Application/Infrastructure` folders
> above — the App/Household/Member domain is still small enough that the
> extra layering isn't earning its keep yet. Revisit this once a domain
> (e.g. Meals+Groceries) grows enough business logic to justify its own
> namespace.

---

# 4. Core Domain Model

The most important architectural decision is:

> **User and Member are different entities.**

A `User` represents an authentication account.

A `Member` represents a person in a household.

A member may exist without a user account.

```text
User
 │
 └──── optional ──── Member
                       │
                       ├── HouseholdMembership
                       ├── Events
                       ├── Requests
                       ├── Tasks
                       └── Location
```

Example:

```text
Santos Household

Mom
 ├── User Account ✓
 └── Member

Dad
 ├── User Account ✓
 └── Member

Anna
 ├── User Account ✓
 └── Member

Ben
 ├── User Account ✗
 └── Member

Mia
 ├── User Account ✗
 └── Member
```

When Ben becomes old enough to use the app:

```text
Existing Member
       ↓
Secure activation
       ↓
New User Account
       ↓
Member.user_id updated
```

Existing member-related data remains attached to the same member.

---

# 5. Multi-Household Model

Do not put a single `household_id` directly on the user.

A person may belong to multiple households.

Recommended relationship:

```text
User
 ↓
Member
 ↓
HouseholdMembership
 ↓
Household
```

Conceptually:

```text
                    ┌── Household A
                    │
Member ─────────────┼── Household B
                    │
                    └── Household C
```

A membership should contain information such as:

- household_id
- member_id
- role
- status
- joined_at
- permissions as appropriate

---

# 6. Household Roles

Recommended initial roles:

```text
Owner
Adult
Minor
Child / Placeholder
```

Permissions should not rely only on UI visibility.

Every protected operation must be authorized by Laravel.

Example:

```text
Flutter:
  Hide "Delete household" button

Laravel:
  Verify requester is owner
```

The backend is the source of truth.

---

# 7. Member Activation Architecture

Placeholder members need to be able to become real users later.

Recommended model:

```text
members
---------
id
name
birth_date
role
user_id nullable
activation_status
created_at
updated_at
```

Activation should use a secure, random token.

Do not use a predictable member ID or a permanent human-readable code as an authentication credential.

Possible flow:

```text
Owner
 ↓
Generate activation link
 ↓
Share link / QR
 ↓
Member opens link
 ↓
Creates account
 ↓
Backend validates activation token
 ↓
Existing Member ←→ New User
 ↓
Token invalidated
```

Activation tokens should be:

- Random
- Single-use
- Expirable
- Revocable

> **Foundation note:** `role` lives on `household_memberships`, not on
> `members` — see section 4 and 5. A member is one row per person,
> reused across every household they join; the illustrative schema above
> (from the original design notes) is simplified for the activation flow
> specifically and predates the multi-household role decision. Activation
> itself (tokens, claim endpoint) is **not implemented yet** — deferred to
> when invitations become the current task, per Phase 1 in `ROADMAP.md`.

---

# 8. Visibility Architecture

Visibility is important because a member may belong to multiple households.

Events and other resources should not automatically be visible everywhere.

Potential visibility scopes:

```text
PRIVATE
HOUSEHOLD
SELECTED_HOUSEHOLDS
ALL_MEMBER_HOUSEHOLDS
```

Example:

```text
Anna belongs to:

Mom's Household
Dad's Household
```

Anna creates:

```text
School
Visibility: ALL_MEMBER_HOUSEHOLDS
```

Both households can see it.

Anna creates:

```text
Private appointment
Visibility: PRIVATE
```

Only Anna can see it unless explicitly shared.

The same principle can later be applied selectively to other resources.

---

# 9. Home Architecture

Home should be an aggregation layer.

It should not duplicate data from other modules.

Conceptually:

```text
                Calendar
                    │
                Requests
                    │
                  Meals
                    │
                Groceries
                    │
                  Tasks
                    │
                  Trips
                    │
               Announcements
                    │
                    ▼
                  HOME
```

Possible API:

```text
GET /api/v1/home
```

The response should contain only data relevant to the authenticated member and selected household.

Example conceptual response:

```text
home
├── greeting
├── today's_events
├── pending_requests
├── family_notes
├── announcements
├── today's_meal
├── grocery_summary
├── upcoming_trips
└── household_status
```

Avoid storing a duplicate "Home Feed" copy of every event.

> **Foundation note:** not implemented yet. The current `HomeScreen` in
> Flutter is a static placeholder (see section 25) that only establishes
> navigation — no `/api/v1/home` endpoint exists. This is Phase 2 work.

---

# 10. Family Notes

Family notes are intentionally temporary.

Data model:

```text
family_notes
------------
id
household_id
author_member_id
content
created_at
expires_at
```

A note is considered active when:

```text
expires_at > now()
```

Notes should be automatically cleaned up through a scheduled Laravel job.

The initial UI lifetime is 24 hours.

Database cleanup may happen slightly after expiration rather than requiring exact deletion at the 24-hour mark.

---

# 11. Calendar Architecture

Core entities:

```text
events
event_participants
event_households
recurring_rules
```

An event should contain information such as:

- creator/member
- title
- description
- start_at
- end_at
- location
- visibility
- recurrence information

The calendar should query events through authorization-aware services rather than exposing all household events directly.

---

# 12. Permission Request Architecture

A request represents an action that requires adult approval.

Conceptual model:

```text
requests
---------
id
requester_member_id
household_id
type
status
target_date
title
description
created_at
updated_at
```

Possible statuses:

```text
PENDING
APPROVED
DECLINED
CANCELLED
EXPIRED
```

Optional conditions:

```text
request_conditions
------------------
id
request_id
content
created_by_member_id
```

Example flow:

```text
Minor
 ↓
Permission Request
 ↓
Adult Notification
 ↓
Approve / Decline
 ↓
Optional Condition
 ↓
Calendar Event
```

---

# 13. Meal Architecture

Core entities:

```text
meal_plans
meal_plan_items
meal_requests
```

A meal plan should belong to a household.

Meal request flow:

```text
Member
 ↓
Meal Request
 ↓
Adult
 ↓
Approve
 ↓
Meal Plan Item
```

Recipes and automated ingredient generation are intentionally deferred.

---

# 14. Grocery Architecture

Core entities:

```text
grocery_lists
grocery_items
```

Potential grocery item fields:

- name
- quantity
- unit
- category
- added_by
- purchased_at
- purchased_by

A grocery list belongs to a household.

Shopping mode is primarily a mobile UI concern and does not require a separate database model initially.

Future:

```text
Meal
 ↓
Recipe
 ↓
Ingredients
 ↓
Grocery Items
```

---

# 15. Tasks & Chores

Potential entities:

```text
tasks
task_assignments
task_recurrences
task_completions
```

Tasks should support:

- One-time tasks
- Recurring tasks
- Assignment
- Due dates
- Completion status

Recurring tasks should be generated/managed by backend jobs rather than Flutter.

---

# 16. Trip Architecture

Potential entities:

```text
trips
trip_participants
trip_itinerary_items
trip_checklists
trip_checklist_items
```

Trip relationships:

```text
Trip
 ├── Participants
 ├── Itinerary
 ├── Checklist
 ├── Tasks
 └── Grocery integration
```

Countdown should not be stored as a mutable database field.

Calculate it from:

```text
trip.start_at - current_time
```

Trip dates and itinerary items can be exposed to the calendar through the application/domain layer.

---

# 17. Location Architecture

Location should be implemented later.

Potential entities:

```text
member_location_settings
member_locations
saved_places
geofences
```

Location sharing modes:

```text
OFF
TEMPORARY
ALWAYS
WHILE_USING_APP
```

Do not continuously store high-frequency GPS points in PostgreSQL without a clear requirement.

Start with coarse/last-known location where possible.

As scale increases, evaluate caching, specialized location storage and realtime infrastructure.

---

# 18. Realtime Architecture

Use Laravel Reverb when realtime behavior adds meaningful value.

Example:

```text
Mom adds Milk
      ↓
Laravel
      ↓
Database
      ↓
Broadcast event
      ↓
Reverb
      ↓
Dad's Flutter app
```

Good realtime candidates:

- Grocery changes
- Task completion
- Permission request updates
- Meal requests
- Trip checklist
- Announcements

Do not make every API operation realtime by default.

---

# 19. Notification Architecture

Use Firebase Cloud Messaging for mobile push notifications.

Conceptual flow:

```text
Laravel
   ↓
Notification Service
   ↓
FCM
   ↓
Flutter
   ↓
User notification
```

Notifications should be generated from backend events/jobs.

Examples:

```text
Permission requested
        ↓
Notify eligible adults

Trip approaching
        ↓
Notify participants

Task due
        ↓
Notify assignee
```

Users should be able to configure appropriate notification preferences.

---

# 20. Background Jobs & Scheduling

Laravel queues and scheduler should handle backend work such as:

- Expiring family notes
- Generating recurring tasks
- Sending reminders
- Trip countdown notifications
- Calendar reminders
- Cleanup jobs
- Notification delivery
- Subscription synchronization

Example:

```text
Laravel Scheduler
       ↓
Dispatch Job
       ↓
Queue Worker
       ↓
Perform Action
```

Do not rely on the mobile application being open to perform server-side scheduled work.

---

# 21. File Storage

Use Amazon S3 for files when file storage is introduced.

Potential files:

- Profile images
- Household images
- Trip attachments
- Future family documents

The database stores metadata and references rather than large binary files.

```text
PostgreSQL
   ↓
file metadata / S3 key

S3
   ↓
actual file
```

---

# 22. Authentication

Initial authentication:

**Laravel Sanctum**

Conceptually:

```text
Flutter
 ↓
Login
 ↓
Laravel
 ↓
Sanctum token/session
 ↓
Secure storage on device
```

Sensitive credentials/tokens should be stored using platform-secure storage mechanisms in Flutter.

Authentication and authorization are separate concerns.

> **Foundation note:** implemented using Sanctum's **personal access
> tokens** (bearer tokens via `createToken()`), not the SPA
> cookie/`EnsureFrontendRequestsAreStateful` flow — the Flutter app is a
> native mobile client, not a same-domain SPA, so token auth is the
> correct Sanctum mode here and avoids CORS/cookie-domain complexity
> entirely. The token is stored on-device via `flutter_secure_storage`
> (Keychain on iOS, EncryptedSharedPreferences on Android).

---

# 23. Authorization

Use Laravel Policies/Gates and domain-level authorization.

Examples:

```text
Owner:
  Can manage household

Adult:
  Can approve minor requests

Minor:
  Can create permission requests

Member:
  Can add grocery items

Event creator:
  Can edit their event
```

Never trust a role or permission supplied by Flutter.

> **Foundation note:** implemented via `App\Policies\HouseholdPolicy`
> (`view`, `update`, `viewMembers`, `addMember`), auto-discovered by
> Laravel's Model→Policy naming convention. All household/member
> endpoints call `$this->authorize(...)` or a `FormRequest::authorize()`
> check — nothing is enforced client-side.

---

# 24. API Design

Use versioned REST APIs.

Example:

```text
/api/v1/auth
/api/v1/households
/api/v1/members
/api/v1/events
/api/v1/requests
/api/v1/meals
/api/v1/groceries
/api/v1/tasks
/api/v1/trips
/api/v1/locations
```

Use consistent:

- HTTP status codes
- Validation responses
- Error format
- Pagination
- Resource representations
- Authorization behavior

> **Foundation note — endpoints implemented so far:**
>
> ```text
> POST  /api/v1/auth/register
> POST  /api/v1/auth/login
> POST  /api/v1/auth/logout        (auth:sanctum)
> GET   /api/v1/auth/me            (auth:sanctum)
>
> GET   /api/v1/households                       (auth:sanctum)
> POST  /api/v1/households                       (auth:sanctum)
> GET   /api/v1/households/{household}            (auth:sanctum)
> PATCH /api/v1/households/{household}            (auth:sanctum)
>
> GET   /api/v1/households/{household}/members    (auth:sanctum)
> POST  /api/v1/households/{household}/members    (auth:sanctum)
> ```
>
> All responses are wrapped `{ "data": ... }` (auth register/login also
> return a top-level `token`). Validation failures return Laravel's
> standard 422 `{ "message": ..., "errors": { field: [...] } }` shape,
> which `ApiException` on the Flutter side parses directly.

---

# 25. Flutter Architecture

Use a layered, feature-oriented architecture.

Conceptually:

```text
lib/
├── core/
│   ├── networking/
│   ├── storage/
│   ├── routing/
│   ├── theme/
│   ├── notifications/
│   └── utilities/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── households/
│   ├── calendar/
│   ├── requests/
│   ├── meals/
│   ├── groceries/
│   ├── tasks/
│   ├── trips/
│   └── locations/
│
└── shared/
    ├── widgets/
    ├── models/
    └── components/
```

The exact state-management library can be selected during Phase 0. Prefer a well-supported approach that keeps business logic out of widgets.

Flutter widgets should primarily handle presentation and user interaction.

> **Foundation note — Phase 0 stack decision:**
>
> | Concern | Choice | Why |
> |---|---|---|
> | State management | `flutter_riverpod` | Compile-safe DI, keeps business logic in controllers/notifiers instead of widgets, easy to test. |
> | Routing | `go_router` | Declarative routes + `redirect` hook, used to drive auth-aware navigation (splash → login/register → create-household → home) from a single place. |
> | HTTP client | `dio` | Interceptors for bearer-token injection and centralized 401 handling. |
> | Token storage | `flutter_secure_storage` | Platform Keychain/EncryptedSharedPreferences, per section 22. |
> | Models | Hand-written `fromJson` | No codegen (`freezed`/`json_serializable`) yet — the model set is small; revisit if it grows enough to justify the build_runner step. |
>
> Each feature currently has `data/` (repository talking to `ApiClient`),
> `domain/` (plain entities), and `presentation/{screens,providers}/`.
> `households/domain` and `members/domain` hold `Household` and `Member`
> respectively since those are used across features; `auth/domain`
> composes them into `AppUser`.

---

# 26. Database Principles

Use PostgreSQL with foreign keys and appropriate indexes.

Important principles:

- Normalize core relational data
- Use foreign keys
- Use timestamps consistently
- Add indexes based on query patterns
- Use transactions for multi-step operations
- Avoid premature denormalization
- Use soft deletion only when there is a clear product requirement
- Keep authorization relationships explicit

Potential high-value indexes will likely include:

```text
household_memberships.household_id
household_memberships.member_id
events.start_at
events.household_id
family_notes.expires_at
grocery_items.grocery_list_id
requests.status
tasks.due_at
trips.start_at
```

Indexes should ultimately be based on measured queries.

> **Foundation note — implemented schema:**
>
> ```text
> users                    (Laravel default: id, name, email, password, ...)
> households                id, name, created_by_user_id, timestamps
> members                   id, name, birth_date nullable, user_id nullable+unique, timestamps
> household_memberships     id, household_id, member_id, role enum(owner|adult|minor|child),
>                            status default 'active', joined_at, timestamps
>                            unique(household_id, member_id)
> personal_access_tokens    (Sanctum default)
> ```
>
> `household_memberships` is both a normal Eloquent model (it has its own
> auto-increment `id` and is queried directly) **and** the pivot model for
> `Household::members()` / `Member::households()`, via `AsPivot` +
> `->using(HouseholdMembership::class)`. This is what makes
> `$household->pivot->role` come back as a cast `HouseholdRole` enum
> instead of a raw string. If you add a field to this table, add it to
> the `withPivot([...])` calls in both `Household` and `Member` or it
> won't show up on the pivot.

---

# 27. Security Principles

The application handles family information and potentially precise location data.

Security requirements:

- HTTPS everywhere
- Secure authentication
- Server-side authorization
- Strong activation tokens
- Rate limiting
- Input validation
- Output filtering
- Secure file uploads
- Audit sensitive actions where appropriate
- Avoid exposing internal IDs unnecessarily
- Minimize collected data
- Encrypt sensitive data where appropriate
- Protect location endpoints carefully
- Never trust mobile-client permissions

Location should receive an additional privacy review before implementation.

---

# 28. Privacy Principles

Privacy should be a product feature.

### Member data

Only expose information necessary for the current household and role.

### Location

Location is opt-in and controlled by the member where appropriate.

### Children

Avoid unnecessary collection and exposure of children's data.

### Notes

Temporary notes expire after 24 hours in the product experience.

### Analytics

Do not send unnecessary family, message or location content to analytics systems.

---

# 29. Offline & Sync Strategy

The app should remain usable during temporary network failures.

Initial strategy:

- Cache recently loaded data where useful
- Show clear offline state
- Retry safe requests
- Avoid silently losing user input

Later, consider local persistence and synchronization for high-value workflows such as:

- Grocery checklist
- Trip checklist
- Tasks

Do not build a complex offline-first synchronization engine before validating that it is necessary.

---

# 30. Observability

Backend should provide:

- Application logs
- Error tracking
- Queue monitoring
- Database monitoring
- API performance monitoring

Mobile should provide:

- Crash reporting
- Error reporting
- Basic performance monitoring

Analytics should measure product behavior without collecting unnecessary private content.

---

# 31. Testing Strategy

## Backend

Use:

- Unit tests
- Feature/API tests
- Authorization tests
- Database integration tests

Important scenarios:

- User cannot access another household's data
- Minor cannot perform adult-only actions
- Placeholder activation works only once
- Expired activation tokens fail
- Private events remain private
- Multi-household visibility works correctly
- Permission requests notify eligible adults
- Household membership changes are enforced

## Flutter

Use:

- Unit tests
- Widget tests
- Integration tests for critical flows

Critical flows:

```text
Registration
Create household
Add member
Invite member
Activate placeholder
Create event
Permission request
Meal request
Add grocery item
Complete grocery item
```

> **Foundation note — current coverage:**
>
> Backend (`php artisan test`, 23 tests, sqlite in-memory):
> registration (success, duplicate email, password mismatch), login
> (success, bad credentials, `/auth/me` requires auth, logout revokes
> token), household creation (becomes owner, second household reuses the
> same member, name required, guests blocked), household authorization
> (non-member forbidden, owner-only update), member creation (owner adds
> placeholder member, adult can add, **minor cannot** add, birth date
> optional, invalid role rejected, non-member forbidden).
>
> Flutter (`flutter test`, 5 tests): login/register form validation
> (required fields, email format, password length/match), and a smoke
> test that an unauthenticated session lands on the login screen.
>
> Not yet covered: placeholder activation (feature doesn't exist yet),
> multi-household visibility beyond the membership list, integration
> tests driving the full register→create-household→add-member flow
> against a real server.

---

# 32. CI/CD

Use GitHub Actions.

Basic pipeline:

```text
git push
   ↓
GitHub Actions
   ├── Backend tests
   ├── Flutter tests
   ├── Static analysis
   └── Build checks
```

Deployment can initially be simple:

```text
main
 ↓
CI passes
 ↓
Deploy Laravel
```

Mobile releases can initially be manual or semi-automated until the release process stabilizes.

> **Foundation note:** not set up yet — there's no git repository
> initialized for either project yet, so there's nothing for Actions to
> run against. Worth doing before the codebase grows much further.

---

# 33. Infrastructure Evolution

## MVP

Keep infrastructure simple:

```text
Flutter
   ↓
Laravel
   ↓
PostgreSQL
```

## Later

Add only what the product requires:

```text
             ┌── Reverb
             ├── FCM
Flutter ─────┤
             ├── S3
             ├── Maps
             └── RevenueCat
                    │
                    ▼
                 Laravel
                    │
                    ▼
               PostgreSQL
```

Do not introduce microservices, Kubernetes or event-driven distributed infrastructure prematurely.

---

# 34. Monetization Architecture

Subscription state should be associated with the household rather than individual members.

Conceptually:

```text
Household
   ↓
Subscription
   ↓
Entitlements
   ↓
Feature access
```

Example:

```text
Household
├── plan: free
├── max_members: 5
├── multiple_households: false
├── advanced_location: false
└── trip_planner: false
```

Later:

```text
Household
├── plan: premium
├── max_members: 15
├── multiple_households: true
├── advanced_location: true
└── trip_planner: true
```

Flutter should not be the source of truth for entitlements.

Laravel should enforce feature access.

RevenueCat can synchronize mobile subscription status with the backend.

---

# 35. Recommended Architecture Summary

```text
                         ┌──────────────────────┐
                         │       Flutter        │
                         │     iOS / Android    │
                         └──────────┬───────────┘
                                    │
                              REST / JSON
                                    │
                         ┌──────────▼───────────┐
                         │       Laravel        │
                         │     Modular API      │
                         ├──────────────────────┤
                         │ Auth                 │
                         │ Households           │
                         │ Members              │
                         │ Calendar             │
                         │ Requests             │
                         │ Meals                │
                         │ Groceries            │
                         │ Tasks                │
                         │ Trips                │
                         │ Locations            │
                         │ Notifications        │
                         └──────────┬───────────┘
                                    │
                         ┌──────────▼───────────┐
                         │      PostgreSQL      │
                         └──────────────────────┘

             Supporting services introduced as required

       ┌────────────┬────────────┬─────────────┬──────────────┐
       │            │            │             │              │
       ▼            ▼            ▼             ▼              ▼
    Reverb        FCM           S3         Maps Provider   RevenueCat
  Realtime     Push Push      Storage        Location      Billing
```

---

# 36. Architectural North Star

The system should remain centered around:

```text
                    USER
                     │
                  MEMBER
                     │
            ┌────────┴────────┐
            │                 │
       HOUSEHOLD A       HOUSEHOLD B
            │                 │
            └────────┬────────┘
                     │
              FAMILY SERVICES
                     │
     ┌───────────────┼────────────────┐
     │               │                │
 Calendar         Requests         Meals
     │               │                │
 Groceries         Tasks            Trips
     │               │                │
     └───────────────┼────────────────┘
                     │
                    HOME
```

**Home is the aggregation point.**

The domain entities own their data and business rules; Home presents the most relevant information from those domains.

This structure should allow the application to grow from a personal project into a production application without requiring a complete architectural rewrite.

---

# 37. Foundation Implementation Notes

What actually exists on disk today, and how to run it. Read this before
assuming something described earlier in this document is built — the
`Foundation note` callouts above mark exactly what's implemented per
section; this is the consolidated setup/reference view.

## Project locations

Two separate project roots (no monorepo):

```text
Flutter app:  c:\Users\Robina\Projects\Flutter\homi
Laravel API:  c:\Users\Robina\Projects\laragon\www\homi-api
```

## Backend setup

```bash
cd c:\Users\Robina\Projects\laragon\www\homi-api

# 1. Start Postgres (requires Docker Desktop + WSL2)
docker compose up -d

# 2. Install deps / configure (already done once, for reference)
composer install
cp .env.example .env   # already has pgsql pointed at the compose service
php artisan key:generate

# 3. Migrate
php artisan migrate

# 4. Run
php artisan serve --port=8010
```

`pdo_pgsql`/`pgsql` were enabled in this machine's Laragon PHP 8.3
`php.ini` (they ship commented out by default) — required for Laravel to
talk to Postgres at all.

Until Docker/Postgres is running, `.env` still works against the
`database/database.sqlite` file Laravel creates by default if you switch
`DB_CONNECTION` back to `sqlite` — useful for quick manual testing without
Docker. The automated test suite always uses in-memory sqlite regardless
(configured in `phpunit.xml`), so `php artisan test` works with zero setup
either way.

Run tests: `php artisan test` (23 passing).

## Flutter setup

```bash
cd c:\Users\Robina\Projects\Flutter\homi
flutter pub get

# Point at the API — 127.0.0.1 works for iOS simulator/desktop/web;
# Android emulator needs 10.0.2.2 instead of 127.0.0.1:
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8010/api/v1
```

Run tests: `flutter test` (5 passing). Static analysis: `flutter analyze`
(clean).

## What's implemented

- Register, login, logout, `/auth/me` (Sanctum bearer tokens)
- Create household (creator becomes Owner; reuses an existing Member
  profile if the user already has one from another household)
- List my households, view/update a household (Owner-only update)
- Add a household member (Owner/Adult only), list members
- Full authorization via `HouseholdPolicy`, enforced server-side only
- Flutter: splash → login/register → create-household → home, all driven
  by `go_router` redirects off a single `AuthController` (Riverpod)
- Home screen and member-management screen are functional but
  intentionally minimal placeholders per the roadmap

## What's deliberately not implemented yet

- Invitations / QR / placeholder-member activation (Phase 1 remainder)
- `/api/v1/home` aggregation endpoint (Phase 2)
- Everything from Calendar onward (Phase 3+)
- Git repository / CI pipeline for either project
