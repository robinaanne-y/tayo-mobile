# Family Management App — Roadmap

> **Status:** Phase 0 (Product & Technical Foundation) and the first slice of
> Phase 1 (accounts, households, members) are implemented. See
> `ARCHITECTURE.md` → "Foundation Implementation Notes" for exactly what
> exists today and how to run it.

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

# Phase 1 — Accounts & Households (in progress — core slice done)

## Features

- [x] Account registration
- [x] Login/logout
- [ ] User profile (edit)
- [x] Create household
- [ ] Household profile (richer view/settings)
- [x] Add household members
- [x] Adult/minor/child roles
- [ ] Invite link
- [ ] QR invitation
- [x] Placeholder members
- [ ] Member profiles (detail/edit screen)
- [x] Household membership
- [x] Multiple household membership (data model + API support)
- [ ] Household switching (UI)
- [ ] Placeholder member activation
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

> Not yet implemented: the activation-token flow itself. The `members`
> table already supports it (`user_id` nullable), but no token/claim
> endpoints exist yet — deferred until invitations are needed.

### Milestone

A user can:

> Register → Create household → Add family members → Invite members → Manage household

(Invite/QR flow still pending — everything before it works end to end.)

---

# Phase 2 — Home & Family Feed

## Features

- Today's schedule
- Upcoming events
- Family notes
- 24-hour note expiration
- Announcements
- Reminders
- Pending requests
- Today's meal
- Grocery summary
- Upcoming trip summary
- Household status

## Family Notes

Temporary refrigerator-style messages.

Examples:

- "Good luck on your exam! ❤️"
- "Pizza tonight!"
- "Please remember your umbrella."

Notes are visible for 24 hours and then expire.

## Announcements

Longer-lived household messages.

## Home Principle

Home is an aggregation of information from other modules. It should not become a separate source of duplicate data.

### Milestone

Opening the app immediately answers:

> **"What's happening with my family today?"**

---

# Phase 3 — Calendar & Scheduling

## Features

- Personal schedules
- Shared household calendar
- Month/week/day views
- Event creation
- Event details
- Recurring events
- Event visibility
- Multiple-household visibility
- Member filtering
- Location
- Participants

## Visibility Options

An event may be:

- Private
- Visible to one household
- Visible to multiple households
- Visible to all households the member belongs to

### Milestone

A family can use the app as its shared household calendar.

---

# Phase 4 — Family Requests

## Permission Requests

A minor can request permission to attend an activity.

Example:

```text
Birthday Party
Saturday, 3:00–6:00 PM
John's House
```

Adult actions:

- Approve
- Decline
- Add conditions
- Add notes

Approved requests can optionally become calendar events.

## Meal Requests

Family members can request preferred meals.

Adults can:

- Approve
- Decline
- Move to another day
- Add to the meal plan

### Milestone

The app facilitates family decisions, not just information sharing.

---

# Phase 5 — Meals & Groceries

## Meal Planning

Adults can create weekly meal plans.

Example:

```text
MONDAY
Breakfast — Eggs
Lunch — Chicken Adobo
Dinner — Sinigang

TUESDAY
Breakfast — Pancakes
Lunch — Leftovers
Dinner — Spaghetti
```

Everyone can view the plan.

## Grocery List

- Shared grocery list
- Add items
- Quantity
- Categories
- Added by
- Purchased status
- Shopping mode

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

Do not build the recipe engine in the first MVP.

### Milestone

The family can answer:

> **What are we eating?**

and:

> **What do we need to buy?**

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

# Phase 6 — Tasks & Chores

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

- Create task
- Assign member
- Due date
- Recurrence
- Completion
- Notifications
- Task status

### Milestone

The app answers:

> **"What needs to get done?"**

---

# Phase 7 — Trips & Family Events

The trip planner is intentionally limited to household coordination rather than becoming a full travel platform.

## Features

- Family event/trip
- Trip details
- Dates
- Location
- Participants
- Itinerary
- Itinerary details
- Preparation checklist
- Checklist assignments
- Checklist completion
- Countdown
- Trip tasks
- Trip grocery integration
- Calendar integration
- Home integration
- Trip notes
- Trip status

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

A family can plan, prepare for and coordinate a major family activity from one place.

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
| 1 | Accounts + Households + Members | Critical | Core (in progress) |
| 2 | Home + Family Feed | Critical | Core |
| 3 | Calendar + Scheduling | Critical | Core |
| 4 | Family Requests | Critical | Core |
| 5 | Meals + Groceries | Critical | **MVP** |
| 6 | Tasks + Chores | High | V1.1 |
| 7 | Trips + Events | High | V1.2 |
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
