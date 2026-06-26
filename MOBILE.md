# GreenRoot — Mobile App Reference

> Last updated: 2026-06-26

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

| Mobile | OTP | Role |
|---|---|---|
| `9000000777` | `123456` | Admin |
| `9111111111` | `123456` | Buyer |
| `9222222222` | `123456` | Nursery Owner |
| `9333333333` | `123456` | Driver |
| `9555555555` | `123456` | Manager |

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
| Buying | `lib/features/buying/buying_screen.dart` | Quotations / Orders / Tracking · FAB → new quotation |
| Selling | `lib/features/selling/selling_screen.dart` | Gate: if `!canSell` → CTA; if owner → owner menu; if manager → manager loading queue |
| Driver | `lib/features/driver_section/driver_screen.dart` | Gate: if `!hasDriverProfile` → register CTA; else driver dashboard |
| Profile | `lib/features/profile/profile_screen.dart` | Avatar, My Roles/Access cards, settings, sign out |

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
    ├── nurseries/      # Nursery list, detail
    ├── plants/         # Plant list, detail
    ├── inventory/      # Inventory add, detail
    └── notifications/  # Notifications list
```

---

## Completed Work (as of 2026-06-25)

| Feature | Status |
|---|---|
| Auth flow (splash, login, OTP, create profile) | ✅ |
| MainShell unified 5-tab navigation | ✅ |
| Capabilities model + session provider | ✅ |
| Invite system (`/invite/accept`, `/invite/:uuid`) | ✅ |
| Invite types: MANAGER_INVITE, CUSTOMER_INVITE, DRIVER_INVITE, NURSERY_ONBOARDING_INVITE | ✅ |
| Nursery registration screen (invite-only in V1) | ✅ |
| Quotation list, create, detail | ✅ |
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

---

## Pending Work (Priority Order)

### 1. Loading Workflow Screen (Highest Priority)
- BRD B.10, C.7 — no dedicated loading management screen exists
- Orders in `LOADING` state need tabs: Not Started / In Loading / Loading Completed
- Manager edits lock after `LOADING_COMPLETED`; only owner can reopen
- Route needed: `/orders/:id/loading` or `/nursery/loading`

### 2. Nursery Approval Status Screen
- BRD B.3 — no pending approval screen
- After nursery submission: show status, submitted date, admin comments
- Splash routing must check nursery status on bootstrap

### 3. Driver My Trips
- Driver tab currently links to `/dispatches` (nursery-side, wrong for drivers)
- Needs driver-specific trip list: Upcoming / Active / Completed / Cancelled tabs
- Join Trip flow: drivers use `DRIVER_INVITE` (UUID or QR)

### 4. Splash Smart Routing
- Currently: authenticated → `/home` (no further checks)
- BRD rules: incomplete profile → `/create-profile`; no activity selected → start-activity screen; pending nursery → approval screen
- "Select Starting Activity" screen not yet built

### 5. Sign-up Screen Polish
- Current login screen says "Welcome back" but handles both new + existing users via OTP
- Needs: T&C checkbox, Privacy Policy checkbox, label polish for new users

### 6. QR Scanner
- No `mobile_scanner` package added yet
- Manager/customer/driver join currently uses UUID text input only
- BRD requires QR code scanning

### 7. Tracking Tab (Buying Screen)
- Currently a placeholder CTA linking to `/dispatches`
- BRD D.6: customer should see dispatch status, trip status, map location, delivery proof

---

## API Gaps (Blockers)

| Missing API | Required By | Workaround |
|---|---|---|
| `GET /nurseries/{id}/customers` | Customer list in members screen | Use invites list (CUSTOMER_INVITE accepted) |
| Nursery `PENDING`/`APPROVED`/`REJECTED` status in `/me/workspaces` response | Splash routing + approval status screen | Check nursery detail separately |

---

## Business Rules Enforced in API (Mobile Must Respect)

- **Manager exclusivity:** MANAGER_INVITE rejected if user owns nursery; NURSERY_ONBOARDING_INVITE rejected if user is manager. Handle `409 conflicting_role` response.
- **One nursery per owner:** `POST /nurseries` returns `409 manager_conflict` if user is a manager.
- **Order editing locked after LOADING_COMPLETED:** Hide add/edit/remove item buttons when order is locked.
- **Orders never deleted:** No delete action in mobile UI; show cancel with reason only.
- **Global account control:** Owners can only manage nursery-level relationships. Never show UI that affects another user's global account.

---

## Role Navigation (Bottom Tabs by Capability)

| Role | Home | Buying | Selling | Driver | Profile |
|---|---|---|---|---|---|
| Nursery Owner | ✅ | ✅ (as buyer too) | ✅ owner menu | hidden | ✅ |
| Manager | ✅ | ✅ | ✅ manager queue | hidden | ✅ |
| Buyer only | ✅ | ✅ | CTA to register | hidden | ✅ |
| Driver | ✅ | hidden | hidden | ✅ | ✅ |
| Owner + Driver | ✅ | ✅ | ✅ | ✅ | ✅ |

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
