# GreenRoot — Mobile App Reference

> Last updated: 2026-07-19

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
| Selling / Work | `lib/features/selling/selling_screen.dart` | Owner/manager operational menu, loading queue, orders, quotations, dispatches and sourcing entry |
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
    ├── top_items/      # My Top Items (showcase, max 20; owner + managers edit)
    └── notifications/  # Notifications list
```

---

## Completed Work (as of 2026-07-19)

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
| My Top Items (size, price, notes; tap to edit) — replaced inventory 2026-10-19 | ✅ |
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
| Driver home screen + tracking screen redesigned; QR scan gated behind active trip check | ✅ |
| Onboarding routing fixed: incomplete profile → `/create-profile`; no `initial_activity` → onboarding screen | ✅ |
| Lifecycle presenter centralized: status chips, action labels, and colors driven by single presenter | ✅ |
| Backend capabilities drive all action buttons (orders, dispatches, quotations, market ads) — no frontend role checks | ✅ |
| Order display synced with dispatch lifecycle (delivery state reflected in buyer tracking) | ✅ |
| Market ad capabilities: publish/pause/resume/archive/save driven by backend `capabilities` fields | ✅ |
| Dispatch capabilities: accept/start-trip/complete-trip actions driven by backend `capabilities` fields | ✅ |
| List providers set to `autoDispose` to prevent stale data across role contexts | ✅ |
| Email verification in Edit Profile: "Verify" for an unverified email, "Change" for a verified one, both via `/users/me/email/send-code` + `/verify` (replaced the local-only 123456 placeholder) | ✅ |
| Saving the profile no longer wipes a verified email (email omitted = unchanged) | ✅ |
| SMS Preferences screen (`/sms-preferences`): OTP/payment SMS always on, promotional opt-in switch | ✅ |
| OTP screen shows resend errors (cooldown / hourly limit / SMS down) and 5-minute validity; dev OTP hint only in debug builds | ✅ |
| Owner home dashboard counts correct (API fix 2026-10-17: was showing 0 orders/inventory/drivers/customers) | ✅ |
| CI (`flutter analyze`, `flutter test`), Dependabot (pub + Actions), PR template, `CODEOWNERS` | ✅ |
| All 7 plant pickers search the catalog + 1.66 M WFO botanical names (`lookupPlants`); picking a name not in the catalog adds it (`resolvePickedPlant`), synonyms show "Now called …" (2026-10-19) | ✅ |
| Seller vs buyer is decided per record (`UserCapabilities.sellsFor(nurseryId)`), not by role: an owner/manager buying from another nursery gets buyer-only order/quotation/dispatch UI; no "Editable"/locked/dead icons for people who can't act (2026-10-21) | ✅ |
| Subscription Pay calls the API (renew with `plan_id`, or create) instead of a fake success; success sheet no longer crashes (`en_IN` date locale was never loaded) (2026-10-21) | ✅ |
| Subscription screen: status banner for paused/cancelled/expired, "Subscribe Again" after cancel, "Choose a Plan" when none, no renew while admin-paused, refetches on open; 402 shows "owner can renew in Profile → Subscription" (2026-10-21) | ✅ |
| Profile: "Register Your Nursery" / "Become a Driver" for users without a selling or driving role (onboarding promised roles can be added later) (2026-10-21) | ✅ |
| Profile → "Stop Driving" (same account, back to customer); "Nursery Suspended" screen with reason for owners and managers; reason shown mid-session too (2026-10-21) | ✅ |
| Market ad posting: storage uploads time out (15 s) with a readable error instead of spinning; retries reuse the draft (no duplicate ads); location is asked again on retry; quantity/price fields accept only valid numbers — "40.." used to post the ad as "price on request" (shared `NumberInput` rules on all 14 numeric fields) (2026-10-21) | ✅ |
| Delivery proof upload (presigned `delivery-photos` + JSON `/attachments`; never worked before), trip-accept black screen, Invite Driver on Members → Drivers, delivery contact defaults to the customer, manager/owner homes show drafts again (stale `DRAFT` status) (2026-10-21) | ✅ |
| Trip events save without an error (API wraps `{event}` and expects `remarks`); Back after accepting a trip returns to Home (accept goes home then pushes the trip) and Back on a non-Home tab goes to Home instead of closing the app; driver Home shows the trip right after accepting (2026-10-22) | ✅ |
| Razorpay checkout opens on the chosen method (UPI/Card) with the mobile pre-filled; Cash removed. Resume with the server unreachable no longer signs the user out (it did right after checkout) (2026-10-22) | ✅ |
| Testing fixes (2026-10-22): Selling list refreshes after recall/send/convert; partial loading reachable ("Load Some Items Only" → Loading Workflow on the In Loading tab, item rows, completion waits for quantity saves); Cancel Dispatch button (API `can_cancel`) and the order offers Create Dispatch again; Ask Mango only blocks the screen while a spotlight shows, Back navigates during a guide (closes only the picker), quotation and customer guide texts fixed | ✅ |
| Onboarding review (2026-10-23): "+91" centred in the mobile field and a number keypad; names, nursery name and address title-cased when typed in lowercase (`tidyName`) and fields capitalise as you type; "Welcome, <name>! … One more step" instead of "You're all set!" with a second "Get Started"; Back from Register Nursery / Driver / invite returns to the role choice (it closed the app); driver form shows required-field errors (it silently did nothing), capitalises licence/plate, readable vehicle types; customer tile "My Nurseries" (was cut off) | ✅ |
| Joining a nursery (2026-10-23): invite card and scan sheet show owner (name + mobile ending), place and role duties; manager/driver invites ask "Join <nursery> as manager?" before accepting (`join_confirm.dart`); success names the nursery; customer Home has "Got a code instead? Enter it"; gallery QR failures show a message instead of failing silently | ✅ |
| Local Market chat (2026-10-22): offer sheet and offer cards are coloured by fairness vs the asking price (green ≥ 90%, orange 70–89%, red < 70% with Send disabled; `offer_fairness.dart`, mirrors the API floor); prices with Indian grouping (₹6,400); replaced offers faded; Accept on its own row (the three buttons broke words); deal-agreed chats no longer greyed in the list | ✅ |
| Ask Mango 🥭 tab is draggable: drop it anywhere, it snaps to the nearest side edge and the spot is remembered (`mango_button_pos`) (2026-10-22) | ✅ |
| Subscription payments through Razorpay Standard Checkout (`razorpay_flutter`, `lib/features/subscriptions/razorpay_checkout.dart`): API-priced order → checkout → renew/create sends payment id + signature for verification; cancel / failure / "paid but not applied" messages; falls back to mock when the API has no keys (503); R8 keep-rules in `android/app/proguard-rules.pro` (2026-10-22) | ✅ |
| User help: first-run "How GreenRoot works" tour (3 cards per role, once per role, replay from Profile), glowing next-action button on order / dispatch / trip screens (`NextActionPulse`), and Ask Mango 🥭 guided walkthroughs (below) (2026-10-22) | ✅ |

---

## User Help: Ask Mango 🥭 (2026-10-22)

Offline, predefined walkthroughs (no AI, no API calls). A 🥭 tab on the left edge opens a picker; guides for the current screen are listed first ("For this screen"). Each step dims the screen, cuts a spotlight around the real control, shows a pointing hand and a short instruction with Back / Skip / Next. Tapping the spotlighted control works normally and moves to the next step; on completion the user can Replay. Android Back while Mango is open only closes Mango.

| File | Role |
|---|---|
| `lib/core/mango/mango_guides.dart` | The guides: steps, audiences (guest / owner / manager / customer / driver), screen-context labels |
| `lib/core/mango/mango_finder.dart` | Finds the visible widget for a label (Text, RichText, tooltip, semantics); skips hidden tabs, Offstage and covered routes; widens to the real button / text field / checkbox row |
| `lib/core/mango/mango_controller.dart` | State: picker, step, done; `next` / `back` / `replay` / `exit` |
| `lib/core/mango/mango_layer.dart` | The overlay, mounted once in `app.dart` above the Navigator (so it follows the user across pages and dialogs) |
| `test/core/mango_test.dart` | Guides per role, controller, finder, and the full layer flow with the real app theme |

**RBAC:** guides are offered by audience from the session's capabilities (`_mangoAudience` in `app.dart`); logged-out users get only the signup guide on `/login`. A guide only points at what is on screen, so it can never show an action the user doesn't have.

**Add a guide:** append a `MangoGuide` to `mangoGuides`. Each step lists the labels to spotlight exactly as the screen shows them (first visible one wins); use `advanceOnTap: false` for fields the user types into and `MangoStep.say` for text-only steps.

**Caveats:**
- Targets are matched by visible label, so if a button label is renamed, update the guide too. A missing target shows "Can't see it here?" and the user can still tap Next.
- The layer sits above the app's Overlay. Don't use `Tooltip`s inside it, and give its buttons an explicit size, because the theme makes FilledButtons full width.

---

## Pending Work

### Tracking access (API change 2026-10-17)
- Tracking history is now permission-checked: vehicle history is admin-only; driver history is visible to the driver and connected nurseries; dispatch history to its driver, buyer and seller nursery. Other callers get `403` — screens that call these routes must show a "no access" state instead of an error.

### Select Starting Activity Screen
- After login, users with no `initial_activity` on their account should be routed to a screen where they pick their first role (Buyer, Nursery Owner, Driver)
- Incomplete profile → `/create-profile` is now working; pending nursery → approval screen is done; T&C checkbox done
- The "Select Starting Activity" screen itself is the only onboarding gap remaining

---

## API Gaps (Blockers)

| Missing API | Required By | Workaround |
|---|---|---|
| ~~`GET /nurseries/{id}/customers`~~ | ~~Customer list in members screen~~ | **Fixed** — route now exists in API |
| ~~Nursery status in `/me/workspaces` response~~ | ~~Splash routing + approval status screen~~ | **Fixed** — `nursery_status` now inline in workspace |

---

## Business Rules Enforced in API (Mobile Must Respect)

- **Manager exclusivity:** MANAGER_INVITE rejected if user owns nursery; NURSERY_ONBOARDING_INVITE rejected if user is manager. Handle `409 conflicting_role` response.
- **One nursery per owner:** `POST /nurseries` returns `409 manager_conflict` if user is a manager.
- **Order editing locked after LOADING_COMPLETED:** Hide add/edit/remove item buttons when order is locked.
- **Orders never deleted:** No delete action in mobile UI; show cancel with reason only.
- **Uploads (2026-10-23):** every presign sends `size` (bytes); the API signs it, max 10 MB images / 20 MB attachments.
- **Driver licence photo (2026-10-23):** Register as Driver has an optional *Driving licence photo* (Camera / Gallery, preview, Remove). On submit it goes to the private `attachments` bucket via presign and `licence_photo_url` is sent with the application. Only admins (and the driver) can open it.
- **Plant suggestions (2026-10-23):** every plant search (quotation/order item rows, plant picker sheets for market + top items, buyer order, order edit) offers **Suggest "<query>" to GreenRoot** — as the empty state and as the last row of results (fuzzy botanical matches rarely come back empty). `suggestPlant()` in `features/plants/plant_picker.dart`; the API answers SUBMITTED / ALREADY_SUGGESTED / EXISTS; 10 a day. Admins review; the user gets a notification.
- **Addresses (2026-10-23):** first address is the default (nursery: primary = pickup point); deleting it promotes another; a nursery's last address can't be deleted (Delete is hidden, API 409 `last_address`). Nursery addresses send `is_primary`. Lists reload after every change. Profile → **Nursery Address** (owner) opens them; editing an address offers **Move pin**. GPS reads time out (picker 15 s → last known fix; driver/dispatch 20 s) so a weak signal never hangs a screen or stops trip posting.
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
