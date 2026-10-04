# Family Management App — Roadmap

> **Status:** Phase 0 (Product & Technical Foundation) is implemented, and
> Phase 1 (accounts, households, members, invite links + QR, placeholder
> activation, user profile editing, household switching, member profile
> editing, household profile settings, server-persisted default household)
> is fully implemented. The bottom nav's 5th tab is a "More" settings hub
> (Appearance, Default household, Profile, Family, Household settings,
> Account settings placeholder) rather than a dedicated Family tab; Home's
> own "More" grid links to Trips instead of Profile. Phase 2
> (Home & Family Feed) is in progress — the Home screen layout, Family
> Notes, Announcements, Today's Schedule, "Needs Your Attention"
> (permission + meal requests, each rendered as its own actionable card),
> Today's Meals, Groceries, and the Upcoming Trip section are all real.
> The app's
> color system was overhauled and a real Light/Dark/System theme mode
> shipped (toggle in More → Appearance) — see `ARCHITECTURE.md` §25
> "Foundation note — Theming". Phase 3 is fully done (event CRUD,
> Month/Week/Day views, all 4 visibility levels, participants, location,
> daily/weekly/monthly recurrence). Phase 4 (permission requests) and
> Phase 5 (meal planning, meal requests, shared grocery list) are both
> done — **this is the mobile MVP line**. Phase 6 (one-off and recurring
> tasks/chores, assignable with due dates, self-service completion) and
> Phase 7 (trip planning, itinerary, checklist/grocery integration,
> calendar sync, a Past Trips gallery with memories) are also done, past
> the MVP line. See `ARCHITECTURE.md` →
> "Foundation Implementation Notes" for exactly what exists today and how
> to run it.

## 1. Product Vision

Build a family coordination app that provides one shared space where households can manage everyday family life.

The app should help families:

- Know what is happening today
- Coordinate schedules
- Communicate through lightweight family notes and announcements
- Handle minor permission requests
- Plan meals
- Manage groceries
- Assign chores and tasks
- Plan trips and family events
- Optionally share locations

### Core Product Principle

> **Home should answer: "What's happening with my family today?"**

The application should feel like a **digital family hub / refrigerator board**, rather than a collection of unrelated productivity tools.

---

# 2. Product Pillars

1. **Family-first** — designed around households rather than individual productivity.
2. **Simple** — common actions should require very few steps.
3. **Calm** — colorful but not visually stressful.
4. **Shared by default** — household information should be easy to discover while respecting privacy.
5. **Privacy-first** — especially for children and location sharing.
6. **Flexible households** — one person may belong to multiple households.
7. **Account-independent members** — a person can exist in a household before having an app account.
8. **Connected features** — calendar, meals, groceries, tasks and trips should work together.
9. **Mobile-first** — optimized for everyday phone use.
10. **Scalable without premature complexity** — start as a modular monolith and introduce infrastructure only when needed.

---

# 3. User Roles

| Role | Description |
|---|---|
| **Owner** | Household administrator. Creates the household and manages membership, roles, permissions and household settings. |
| **Adult** | Trusted household member who can manage family coordination features such as meals, trips, tasks and minor requests. |
| **Minor** | Household member who can use the app but may require adult approval for selected actions. |
| **Child / Placeholder** | Household member represented in the system without an app account. |
| **User** | Authentication/account identity. A user account may be linked to a member profile. |

> `User` and `Member` are intentionally separate concepts. A member may exist without an account.

---

# 4. Feature Roadmap

## Phase 0 — Product & Technical Foundation ✅ Implemented

### Product

- Define product requirements
- Define user roles
- Define permissions
- Define household model
- Define multi-household behavior
- Define placeholder-member behavior
- Define visibility rules
- Define notification rules
- Define location privacy rules
- Define subscription boundaries
- Define UX principles

### Technical

- Flutter mobile project
- Laravel API project
- PostgreSQL database
- API versioning conventions
- Authentication architecture
- Authorization architecture
- Database ERD
- API conventions
- Error handling
- Logging
- Environment configuration
- Git repository
- CI/CD foundation

### Milestone

A basic Flutter client can authenticate against Laravel and communicate with PostgreSQL-backed APIs.

---

# Phase 1 — Accounts & Households ✅ Done

## Features

- [x] Account registration
- [x] Login/logout
- [x] User profile (edit)
- [x] Create household
- [x] Household profile (richer view/settings)
- [x] Add household members
- [x] Adult/minor/child roles
- [x] Invite link
- [x] QR invitation
- [x] Placeholder members
- [x] Member profiles (detail/edit screen)
- [x] Household membership
- [x] Multiple household membership (data model + API support)
- [x] Household switching (UI)
- [x] Placeholder member activation
- [x] Basic household permissions

## Placeholder Member Flow

A household can create a member without requiring an account.

Example:

```text
Santos Family

Mom       → Account
Dad       → Account
Anna      → Account
Ben       → Placeholder
Mia       → Placeholder
```

Later:

```text
Ben
 ↓
Creates account
 ↓
Claims existing member profile
 ↓
Previous household data remains associated
```

Use a secure activation token/link rather than treating a permanent referral code as a credential.

Implemented: `member_activation_tokens` + `household_invitations` tables,
generate-link/claim/accept endpoints, and the mobile deep-link (`tayo://activate/<token>`,
`tayo://invite/<token>`) screens. Invite/activation links also render as a
QR code in the share sheet, and a camera-based scan screen (reachable from
the Welcome screen, for someone joining their first household) decodes
either kind and routes straight to the matching screen.

### Milestone

A user can:

> Register → Create household → Add family members → Invite members → Manage household

Invite link and QR invitation (generate + scan) tested end to end,
including a Playwright-driven run with a synthetic camera feed decoding a
real invite QR through to the join-household preview.

## Member Profile Editing

An Owner/Adult can edit a member's name, birth date, and role from the
Family screen's member detail view, and replace their avatar photo
(camera or gallery) independently of the rest of the form. The Owner's
own role is immutable — the field is omitted from the request entirely
for that case rather than resent, since the backend rejects `role`
being present at all for that row. Verified on a real Android device,
including a round-trip bug (submitting the Owner's own unchanged role
value failed validation) found and fixed during that testing.

## Household Profile Settings

An Owner can rename the household and change its accent color/emoji from
a new Household Settings screen (reachable from the bottom nav's More tab,
or via the Family screen pushed from there). The same
color/emoji palette offered at creation time is reused here; a non-Owner
can open the screen to see current settings but can't edit them. Color
and emoji are now persisted server-side (`households.color`/`.emoji`) and
used everywhere a household is shown — the home header pill, the welcome
card, and the household switcher — replacing the fixed 🏡 placeholder and
the `HouseholdVisualPreview`-only approach from initial household
creation. Verified end to end with a Playwright run: create a household
with a chosen color/emoji, confirm it renders correctly on Home, edit it
from Household Settings, and confirm the change round-trips through the
real API and is reflected back on the Family screen.

---

# Phase 2 — Home & Family Feed (in progress — most sections wait on Phases 3-7)

## Features

- [x] Family notes (create, list, delete, 24-hour expiration)
- [x] Today's schedule (real data as of Phase 3's core slice — a
      read-through of today's events; see Phase 3 below)
- [x] Upcoming events (browsing anything beyond today happens on the full
      Calendar screen rather than a second Home widget — see Phase 3)
- [x] Announcements (create, list, delete — Owner/Adult post, anyone reads)
- [ ] Reminders (Phase 9 — read-through of other modules' due dates, no
      dedicated table)
- [x] Pending requests / "Needs Your Attention" (real data from Phase 4's
      permission requests and Phase 5's meal requests, normalized into one
      combined list)
- [x] Today's meal (real data, Phase 5)
- [x] Grocery summary (real data, Phase 5)
- [ ] Upcoming trip summary (data is Phase 7)
- [x] Household status (member avatars row — shipped earlier alongside
      household switching)

Home's layout was redesigned to match a full "family feed" mockup: the
onboarding-style Welcome/Get-Started card is gone (member invites now
live on the Family screen, reachable from the bottom nav's More tab),
each section has a title + right-aligned action
link ("See all", "+ Add note", "Request meal", "View list"), and every
section without a backing feature yet renders its real empty state rather
than fabricated sample data — consistent with how Household Status and
the original Today's Schedule card already worked.

## Family Notes

Temporary refrigerator-style messages. Implemented: `family_notes` table
(`household_id`, `author_member_id`, `content`, `expires_at`), `GET`/`POST`/`DELETE
/api/v1/households/{household}/notes`. Any household member (including a
minor or child) can leave a note; only the author or an Owner/Adult can
delete one. Notes are visible for 24 hours, then excluded from the list
query and eventually purged by an hourly scheduled job (not
exact-to-the-second — the query-time filter is what keeps the list
correct in the meantime). Verified end to end with Playwright: post a
note, see it render with author + "Xh left", delete it, confirm it
round-trips through the real API back to the empty state.

Examples:

- "Good luck on your exam! ❤️"
- "Pizza tonight!"
- "Please remember your umbrella."

## Announcements

Longer-lived household messages — unlike a Family Note, these don't
expire and only an Owner/Adult can post one (a household bulletin, not a
free-for-all). Implemented: `announcements` table (`household_id`,
`author_member_id`, `content`), `GET`/`POST`/`DELETE
/api/v1/households/{household}/announcements`. Any member can read the
list; the author or an Owner/Adult can delete one. Rendered on Home as a
vertical list of cards (not a horizontal scroll like notes, since these
are meant to be read in full and stay around) below Family Notes, with a
"+ Post" action visible only to an Owner/Adult. Verified end to end with
Playwright: post an announcement, see it render with author + relative
time, delete it, confirm it round-trips through the real API back to the
empty state.

## Home Principle

Home is an aggregation of information from other modules. It should not
become a separate source of duplicate data. A dedicated `GET /api/v1/home`
aggregation endpoint (per the API roadmap) is deferred until there are
enough real sources to justify it — Family Notes and Announcements are
the only sections with real data so far, so the mobile client calls their
endpoints directly.

### Milestone

Opening the app immediately answers:

> **"What's happening with my family today?"**

Partially met: the layout, Family Notes, and Announcements are real; the
rest of the feed (schedule, requests, meals, groceries, trips) will fill
in as Phases 3-7 land, without needing another Home redesign — the
sections are already in place.

---

# Phase 3 — Calendar & Scheduling

## Core slice ✅ Implemented

- [x] Personal schedules (private events, visible only to their creator)
- [x] Shared household calendar (household-visible events)
- [x] Month/Week/Day views (`lib/features/calendar/presentation/screens/calendar_screen.dart`
      — Month via `table_calendar`, Week/Day are custom views over the
      same event data)
- [x] Event creation
- [x] Event details / editing
- [x] Event visibility (private / household — see below)
- [x] Events color-coded by creator (a member-color legend in the
      Calendar header, matching each event card's left border and the
      month grid's day markers — reuses the existing
      `AppColors.memberColor(index)` convention, no schema change)
- [x] Home's "Today's Schedule" wired to real data (Phase 2 leftover,
      built together with this slice since it's a read-through of the
      same `events` endpoint)
- [x] Participants — tag which household members are involved in an
      event, via a tappable-avatar picker in the add/edit sheet;
      displayed as an overlapping avatar stack on each event card
- [x] Location — a free-text optional field, shown on the event card
      with a map-pin icon when set
- [x] Member filtering — the Calendar header's legend row doubles as a
      filter: tap a member to narrow the calendar/day list to their
      events, tap again (or select more) to combine/clear. Entirely
      client-side, no new endpoint needed
- [x] Multiple-household visibility — `selected_households` (pick
      specific other households you belong to, via a household-chip
      picker that appears once that visibility is chosen) and
      `all_member_households` (every household you belong to,
      automatically). A member belonging to more than one household sees
      the right subset of events in each.
- [x] Recurring events — a "Repeats" section in the add-event sheet
      (Daily/Weekly/Monthly, an interval, weekday toggles for weekly, and
      an end date or occurrence count) shown only when creating a new
      event. The pattern is immutable after creation: editing or deleting
      an occurrence that belongs to a series prompts for "This event" or
      "This and following events" before proceeding, rather than exposing
      a way to change the recurrence rule itself. Event tiles show a
      repeat icon with a short summary (e.g. "Repeats weekly on Mon,
      Wed") when applicable.

## Deferred to a later increment

- [ ] Editable recurrence patterns (currently create-only/immutable)
- [ ] A true "all events" edit/delete scope beyond "this"/"this and
      following"
- [ ] Open-ended ("never ends") recurring series — every recurring event
      today must specify an end date or occurrence count

## Visibility Options

All 4 implemented:

- Private (creator only)
- Visible to one household
- Visible to selected households
- Visible to all households the member belongs to

### Milestone

A family can use the app as its own household's shared calendar (create,
edit, delete events; all 4 visibility levels; Month/Week/Day views;
color-coded by who owns each event; tag which members are involved and
where; filter down to one or more members; daily/weekly/monthly
recurrence), and a member belonging to multiple households sees the
right subset of events in each.

---

# Phase 4 — Family Requests — ✅ Done (Permission Requests)

## Permission Requests

A member (in practice usually a minor) can request permission to attend
an activity. Example:

```text
Birthday Party
Saturday, 3:00–6:00 PM
John's House
```

Adult actions:

- [x] Approve (with an optional response note and/or condition)
- [x] Decline (with an optional response note)
- [x] Add conditions (independently of approving/declining)
- [x] Add notes (the `response_note` on approve/decline)

- [x] Approved requests can optionally become calendar events — an "Add
      to calendar" checkbox on the approve sheet, only shown when the
      request has a time window.
- [x] A new "Requests" screen (list with status filter chips, a "New
      request" sheet with an optional time-window picker) reached from
      Home's header bell (which also carries a badge count) or the
      "Permissions" tile under Home's "More" row.
- [x] Home's "Needs Your Attention" section shows real pending requests
      the viewer can act on (Owner/Adult, never their own request).

The recurrence pattern for who can act mirrors the API: only an
Owner/Adult who isn't the requester sees Approve/Decline; the requester
sees Edit/Cancel while their request is still pending.

## Meal Requests

Family members can request preferred meals.

Adults can:

- Approve
- Decline
- Move to another day
- Add to the meal plan

### Milestone

The app facilitates family decisions, not just information sharing. Met
for both permission requests and meal requests (Phase 5).

---

# Phase 5 — Meals & Groceries — ✅ Done

## Meal Planning

Owners/Adults set a meal for any day's fixed Breakfast/Lunch/Dinner slot
(`MealsScreen`'s week strip + three slot cards, week starting Monday);
everyone else gets a "Request this meal" flow instead of a direct edit —
anyone, including other adults, can submit a request. Weeks aren't grouped
behind a parent object client-side either — the screen just queries a date
range, matching the API's no-`meal_plans`-table decision (see
`tayo-api`'s `docs/ROADMAP.md` Phase 5 for why).

**Meal approver** — a household can optionally delegate meal-plan
management to one member (`households.meal_approver_member_id`, set from
Household Settings). When set, that member fully replaces the Owner/Adult
check for editing the plan and acting on requests — even the Owner must
go through the request flow once delegated. Pending requests whose date
has passed are shown as expired. The Meals screen also has a read-only
"Week Overview" grid of the whole week's slots.

## Grocery List

- Shared grocery list — any member (including minors) can add an item and
  toggle it purchased/unpurchased; editing or deleting an item, and
  bulk-clearing purchased items, is Owner/Adult-only. Still deliberately
  more permissive than meal plans for the add/toggle actions, since the
  stakes of those are low and full collaboration is the point.
- Add items with quantity, unit, category
- Added-by shown per item
- Purchased status, with purchased items collapsed to the bottom and a
  "Clear" action (Owner/Adult-only) to bulk-remove them
- Shopping mode is just checking items off — no separate mode toggle
- Category dropdown + filter chips; swipe-to-reveal Edit/Delete actions
  (Owner/Adult only)

## Future Meal → Grocery Integration

Eventually:

```text
Meal Plan
    ↓
Recipe
    ↓
Ingredients
    ↓
Grocery List
```

Did not build the recipe engine in this MVP, per the plan above.

### Milestone

The family can answer:

> **What are we eating?**

and:

> **What do we need to buy?**

Met.

---

# MVP

The recommended MVP ends at Phase 5.

### MVP includes

- Accounts
- Households
- Multiple households
- Members
- Placeholder members
- Invitations
- Member activation
- Home
- Family notes
- Announcements
- Reminders
- Calendar
- Scheduling
- Permission requests
- Meal planning
- Meal requests
- Grocery list

The MVP should be polished enough for real families to use rather than trying to include every planned feature.

---

# Phase 6 — Tasks & Chores ✅ Done

## Features

### Chores

Recurring household responsibilities.

Examples:

- Wash dishes
- Take out trash
- Clean bathroom

### Tasks

One-off responsibilities.

Examples:

- Buy light bulb
- Submit school form
- Check car

### Capabilities

- [x] Create task
- [x] Assign member
- [x] Due date
- [x] Recurrence (daily/weekly/monthly, same "Repeats" picker as Calendar
      events, create-only — no editing an existing pattern)
- [x] Completion — self-service: the assignee (even a minor) or an
      Owner/Adult can mark a task complete/incomplete; creating/editing/
      deleting a task is Owner/Adult only
- [ ] Notifications — deferred to Phase 9 (push/realtime infra); Home's
      Tasks section and the list screen's overdue styling are the only
      "reminder" today
- [x] Task status (pending/overdue/completed, filterable)

Reached via a plain `/tasks` route — not a 6th bottom-nav tab, since the
nav bar is already full at 5/5 — from Home's "Chores" tile, a new Home
Tasks summary section, and a More-hub list entry. Task completion is
deliberately kept out of the `_AttentionItem`/"Needs Your Attention"
system (that's for requester-vs-approver flows like permission/meal
requests); it's a direct self-service action, same as toggling a grocery
item purchased.

### Milestone

The app answers:

> **"What needs to get done?"**

Met for one-off and recurring tasks; push reminders are Phase 9.

---

# Phase 7 — Trips & Family Events ✅ Done

The trip planner is intentionally limited to household coordination rather than becoming a full travel platform.

## Features

- [x] Family event/trip
- [x] Trip details
- [x] Dates
- [x] Location (destination)
- [x] Participants
- [x] Itinerary (timed items)
- [x] Itinerary details
- [x] Preparation checklist / Trip tasks — the same thing: a checklist
      item is just a Phase 6 Task scoped to the trip (`trip_id`), not a
      separate model, so checklist and trip-task capabilities share one
      implementation
- [x] Checklist assignments — inherited from Task's `assigned_member_id`
- [x] Checklist completion — inherited from Task's self-service
      complete/uncomplete (the assignee or an Owner/Adult)
- [x] Countdown (computed `days_until`, never stored)
- [x] Trip grocery integration — a grocery item scoped to the trip via
      `trip_id`, same filtered-view approach as the checklist
- [x] Calendar integration — the trip's dates and itinerary appear as
      read-only entries in the shared Calendar (tapping one opens Trip
      detail, not the event editor), synthesized by the API at read time
      with zero duplicate `events` rows created
- [x] Home integration — an "Upcoming Trip" section with countdown
- [x] Trip notes (free text)
- [x] Trip status (planning/confirmed/completed/cancelled)
- [x] Trip thumbnail (Owner/Adult upload) and a Past Trips gallery —
      grid of past trips by thumbnail/title/year
- [x] Trip memories — one "memorable moment" note per member per trip,
      any member can add their own, author or Owner/Adult can delete

## Example

```text
Family Camping Trip

12 days to go
Sept 3–5
Rizal

ITINERARY
7:00 AM — Leave home
9:00 AM — Arrive
10:00 AM — Set up camp

CHECKLIST
☑ Book accommodation
☑ Buy tickets
☐ Pack clothes
☐ Prepare snacks
☐ Charge power banks
```

### Milestone

A family can plan, prepare for and coordinate a major family activity from one place. Met, plus a Past Trips gallery with thumbnails and per-member memories once the trip is over.

---

# Phase 8 — Family Map & Location

Location is intentionally deferred because it introduces privacy, battery, background processing and infrastructure complexity.

## Features

- Family map
- Location sharing
- Temporary location sharing
- Always sharing
- While-using-app sharing
- Location privacy controls
- Arrival/departure notifications
- Saved places
- Optional family safety status

## Privacy Principles

- Location sharing is opt-in
- Users control their sharing where appropriate
- Do not expose precise location to unauthorized members
- Avoid collecting location when it is not needed
- Clearly explain location permissions

### Milestone

A family can answer:

> **"Where is everyone?"**

without making location sharing mandatory.

---

# Phase 9 — Realtime, Notifications & Automation

## Realtime

Introduce Laravel Reverb/WebSockets where live updates materially improve the experience.

Candidates:

- Grocery list changes
- Task completion
- Permission requests
- Meal requests
- Trip checklist updates
- Household announcements

## Notifications

- Permission requests
- Calendar reminders
- Meal requests
- Grocery updates
- Task reminders
- Trip reminders
- Location alerts

## Automation

Examples:

- Weekly meal planning reminder
- Recurring grocery reminder
- Trip preparation reminders
- Event reminders
- Recurring chore generation

Use Laravel Scheduler, queues and jobs rather than implementing business automation inside Flutter.

### Milestone

The application proactively helps families rather than simply storing information.

---

# Phase 10 — Monetization

Do not build billing before validating the product.

## Potential Free Tier

- One household
- Basic members
- Basic calendar
- Home
- Family notes
- Grocery list
- Basic meal planning
- Basic requests

## Potential Premium Tier

- Multiple households
- Larger households
- Advanced trip planning
- Advanced location
- Recurring automation
- Advanced notifications
- Extended history
- Family storage

## Potential Pricing Model

Start with one household subscription rather than charging individual family members.

Example hypothesis:

- Free — ₱0
- Family Plus — approximately ₱199/month
- Annual discount

Pricing should be validated with real users.

## Subscription Technology

Use RevenueCat for mobile subscription management and connect subscription entitlements to Laravel.

### Milestone

The application has a sustainable monetization model based on household value rather than advertising.

---

# 5. Condensed Roadmap

| Phase | Focus | Priority | Target |
|---|---|---|---|
| 0 | Product + Architecture | Critical | Foundation ✅ |
| 1 | Accounts + Households + Members | Critical | Core (nearly done — profile/settings screens remain) |
| 2 | Home + Family Feed | Critical | Core |
| 3 | Calendar + Scheduling | Critical | Core |
| 4 | Family Requests | Critical | Core |
| 5 | Meals + Groceries | Critical | **MVP** ✅ |
| 6 | Tasks + Chores | High | V1.1 ✅ |
| 7 | Trips + Events | High | V1.2 ✅ |
| 8 | Family Map + Location | Medium | V1.3 |
| 9 | Realtime + Automation | Medium | V1.4 |
| 10 | Monetization | Later | After validation |

---

# 6. Definition of Done

A phase is not complete simply because the screens exist.

A feature should generally have:

- UI implementation
- API implementation
- Database implementation
- Authorization rules
- Validation
- Error handling
- Loading states
- Empty states
- Offline/error considerations where appropriate
- Unit tests
- Integration/API tests
- Mobile tests where appropriate
- Analytics event when useful
- Documentation
- Security/privacy review where applicable

---

# 7. Development Philosophy

Build a **modular monolith first**.

Do not start with microservices, Kubernetes or a complicated distributed architecture.

Recommended progression:

```text
MVP
Flutter
   ↓
Laravel
   ↓
PostgreSQL

Later
   ↓
Reverb
   ↓
Queues
   ↓
FCM
   ↓
S3
   ↓
Maps
   ↓
RevenueCat
```

Introduce infrastructure when a feature requires it.
