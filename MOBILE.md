# GreenRoot — Mobile App Reference

> Last updated: 2026-06-28

---

## What It Is

Flutter mobile app for all GreenRoot user roles — nursery owners, managers, drivers, and buyers.  
Single app, role-based capability rendering after login.

---

## Stack

Flutter · Dart · Riverpod (StateNotifierProvider) · GoRouter · Dio · flutter_secure_storage

---

## Run Locally

```bash
flutter pub get
flutter run -d <device-id>

# Physical Android device with local API (ADB tunnel):
adb reverse tcp:8080 tcp:8080
flutter run --release -d <device-id>
```

API runs at `http://127.0.0.1:8080` via ADB tunnel from Mac.

---

## Dev Login

| Mobile | OTP | Role | Name |
|---|---|---|---|
| `9000000000` | `123456` | Admin + Super Admin | GreenRoot Admin |
| `9100000000` | `123456` | Nursery Owner | Priya Owner |
| `9200000000` | `123456` | Manager | Gumastha Manager |
| `9300000000` | `123456` | Buyer | Ravi Buyer |
| `9400000000` | `123456` | Driver | Raju Driver |

---

## Architecture (Phase 4 — Unified Shell)

All authenticated users route to `/home` → `MainShell` (5-tab IndexedStack).  
Capability-based rendering: tabs show/hide content based on the user's active workspaces.

### `UserCapabilities` model
File: `lib/features/auth/data/models/capabilities_model.dart`  
Built via: `UserCapabilities.fromWorkspaces(workspaces)` called from `SessionState.capabilities`

Fields: `isNurseryOwner`, `isManager`, `hasDriverProfile`, `ownedNurseryId`, `ownedNurseryName`, `managedNurseries`, `canSell`, `primaryNurseryId`

### MainShell tabs

| Tab | File | Logic |
|---|---|---|
| Home | `lib/features/home/home_screen.dart` | Greeting, role badges, capability-based action cards |
| Buying | `lib/features/buying/buying_screen.dart` | Buyer-scoped quotations, orders, and delivery tracking |
| Selling / Work | `lib/features/selling/selling_screen.dart` | Owner/manager operational menu, loading queue, orders, quotations, dispatches, plant requests, and sourcing entry |
| Driver | `lib/features/driver/driver_home_screen.dart` and `lib/features/driver/driver_trips_screen.dart` | Driver trips, scan, tracking, delivery proof |
| Profile | `lib/features/profile/profile_screen.dart` | Avatar, My Roles/Access cards, settings, sign out |

Role tab sets:

| Role | Tabs |
|---|---|
| Nursery Owner | Home, Buying, Selling, Profile |
| Manager | Home, Buying, Work, Profile |
| Buyer only | Home, Buying, Profile |
| Driver only | Home, Driver, Profile |

### Auth Flow

```
Splash → /home (authenticated) or /login (not authenticated)
OTP success → /create-profile (no name) or /home
Create profile → /home
Old role routes (/home/buyer, /home/nursery-owner, etc.) → redirect to /home
/home/admin → AdminDashboard (kept separate)
```

---

## Feature Directory

```
lib/
├── app/            # Router, theme, app entry
├── core/           # ApiClient, errors, constants, widgets, theme
│   └── constants/api_constants.dart  # All API endpoint paths
└── features/
    ├── auth/           # OTP login, session, RBAC, capabilities model
    ├── home/           # Unified home screen
    ├── buying/         # Quotations, orders, tracking (buyer/owner view)
    ├── selling/        # Owner + manager selling screens
    ├── driver_section/ # Driver dashboard + trip management
    ├── profile/        # Profile + settings
    ├── members/        # Owner manages managers + customers (invite codes)
    ├── orders/         # Order list, create, detail
    ├── quotations/     # Quotation list, create, detail
    ├── dispatches/     # Dispatch list, detail, tracking
    ├── requests/       # Plant request list, create, detail
    ├── sourcing/       # Plant Sourcing Network discovery + posts
    ├── nurseries/      # Nursery list, detail
    ├── plants/         # Plant list, detail
    ├── inventory/      # Inventory add, detail
    └── notifications/  # Notifications list
```

---

## Completed Work (as of 2026-07-04)

| Feature | Status |
|---|---|
| Auth flow (splash, login, OTP, create profile) | ✅ |
| MainShell unified 5-tab navigation | ✅ |
| Capabilities model + session provider | ✅ |
| Invite system (`/invite/accept`, `/invite/:uuid`) | ✅ |
| Invite types: MANAGER_INVITE, CUSTOMER_INVITE, DRIVER_INVITE, NURSERY_ONBOARDING_INVITE | ✅ |
| Nursery registration screen (invite-only in V1) | ✅ |
| Quotation list, create, detail | ✅ |
| Quotation manager visibility scoping (private-default: manager sees own only) | ✅ |
| Quotation list tabs: owner (All / Unassigned / Mine), manager (All / Created by Me / Assigned to Me) | ✅ |
| Quotation list: assignment badge (Unassigned warning / assigned manager name) | ✅ |
| Quotation detail: Assignment card for owner (assign / reassign / unassign) | ✅ |
| Quotation detail: origin label for manager (created by you / assigned by owner) | ✅ |
| Quotation create: optional manager pre-assignment picker (owner only) | ✅ |
| Order list, create, detail | ✅ |
| Dispatch list, detail, tracking | ✅ |
| Plant request list, create, detail | ✅ |
| Nursery list, detail | ✅ |
| Plant list, detail | ✅ |
| Inventory add, detail | ✅ |
| Notifications list | ✅ |
| Members management screen (`/nursery/members?id=&tab=0\|1`) | ✅ |
| Manager tab: list active managers + pending invites + "Invite Manager" CTA | ✅ |
| Customer tab: linked customers + pending invites + "Invite Customer" CTA | ✅ |
| Plant Sourcing Network: nearby members + Need/Available posts | ✅ |
| Loading Workflow Screen (`/orders/loading?nursery=`) | ✅ |
| Driver My Trips (`/driver/trips`) | ✅ |
| Buyer Tracking Tab (real dispatch list, In Transit / Being Loaded / Delivered) | ✅ |
| Buyer quotation accept/reject in list card (CUSTOMER_SENT + APPROVED + SENT) | ✅ |
| Buyer quotation accept/reject in detail screen | ✅ |
| Buying tab sections for quotations, orders, tracking | ✅ |
| Owner/manager create actions consolidated into global FAB | ✅ |
| Role home dashboards aligned to buyer / owner / manager / driver lifecycle work | ✅ |
| MainShell role tabs realigned to `Mobile_UI_UX_Plan.md` | ✅ |
| Deep-link guards for customer/driver/internal role leaks | ✅ |
| My Addresses screen (`/my-addresses`) — add, edit, delete delivery addresses | ✅ |
| My Payments screen (`/my-payments`) — payment history for buyer | ✅ |
| `/nurseries` route for buyers — browse active nurseries | ✅ |
| `/plants` route for buyers — browse plant catalog | ✅ |
| Profile screen: My Addresses + Payment History links | ✅ |
| Buyer home: Browse Nurseries + Plant Catalog explore cards | ✅ |

---

## Pending Work (Priority Order)

### 1. Nursery Approval Status Screen ✅
- BRD B.3 — ~~no pending approval screen~~ — **DONE**
- Pending screen now shows submitted date from nursery `created_at`
- Rejected screen now shows `rejection_reason` from API + `rejected_at` date
- API workspace response now includes `nursery_status` inline (eliminates separate status call)
- Splash routing uses workspace status with fallback to `/nurseries/owned`

### 2. Splash Smart Routing
- Currently: authenticated → `/home` (no further checks)
- BRD rules: incomplete profile → `/create-profile`; no activity selected → start-activity screen; pending nursery → approval screen (done)
- "Select Starting Activity" screen not yet built

### 3. Sign-up Screen Polish ✅
- Login screen already says "Welcome to GreenRoot" (handles new + existing users)
- T&C + Privacy Policy checkbox added — must be checked to enable Send OTP

---

## API Gaps (Blockers)

| Missing API | Required By | Workaround |
|---|---|---|
| `GET /nurseries/{id}/customers` | Customer list in members screen | Use invites list (CUSTOMER_INVITE accepted) |
| ~~Nursery status in `/me/workspaces` response~~ | ~~Splash routing + approval status screen~~ | **Fixed** — `nursery_status` now inline in workspace |

---

## Business Rules Enforced in API (Mobile Must Respect)

- **Manager exclusivity:** MANAGER_INVITE rejected if user owns nursery; NURSERY_ONBOARDING_INVITE rejected if user is manager. Handle `409 conflicting_role` response.
- **One nursery per owner:** `POST /nurseries` returns `409 manager_conflict` if user is a manager.
- **Order editing locked after LOADING_COMPLETED:** Hide add/edit/remove item buttons when order is locked.
- **Orders never deleted:** No delete action in mobile UI; show cancel with reason only.
- **Global account control:** Owners can only manage nursery-level relationships. Never show UI that affects another user's global account.

---

## Role Navigation (Current Cleanup Target)

| Role | Current Tabs | Cleanup Target |
|---|---|---|
| Nursery Owner | Home, Buying, Selling, Profile + create FAB | Keep; refine Selling internals |
| Manager | Home, Buying, Work, Profile + create FAB | Keep; refine Work internals |
| Buyer only | Home, Buying, Profile | Keep; add true buyer direct-buy flow |
| Driver | Home, Driver, Profile + scan action | Keep; refresh screenshots |
| Admin/Super Admin | Mobile-safe admin notice | Web portal only notice |

Cleanup progress is tracked in `MOBILE_UI_CLEANUP_TRACKER.md`.

Major UI milestones must now include role screenshots in `/private/tmp/greenroot-mobile-visuals`.

---

## Key Routes

| Route | Screen |
|---|---|
| `/home` | MainShell (5-tab) |
| `/login` | Login (mobile input) |
| `/otp` | OTP verify |
| `/create-profile` | Profile setup (first time) |
| `/invite/accept` | Invite accept (UUID input) |
| `/invite/:uuid` | Invite accept (direct link) |
| `/nursery/members?id=&name=&tab=` | Members management (owner) |
| `/home/admin` | Admin dashboard (separate) |
