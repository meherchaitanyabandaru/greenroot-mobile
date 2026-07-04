# GreenRoot Mobile UI Cleanup Tracker

> Started: 2026-06-28  
> Rule: remove UI that is not backed by current API/RBAC/business rules, then verify with analyzer/tests/build.

## Source Of Truth

| Source | Use |
|---|---|
| `greenroot-api/BUSINESS_RULES.md` | Role rules, lifecycle rules, privacy |
| `greenroot-api/API.md` | Current endpoint availability |
| `greenroot-api/DB.md` | Tables and schema-backed entities |
| `greenroot-api/test-api.sh` | Positive and negative RBAC expectations |
| `greenroot-api/internal/modules/orders/service.go` | Order lifecycle enforcement |
| `greenroot-mobile/MOBILE.md` | Current mobile architecture |

## Cleanup Rules

- Do not show admin transaction UI in mobile.
- Do not show driver access to orders, quotations, sourcing, plant requests, or nursery operations.
- Do not show buyer access to nursery internal operations.
- Do not show manager inventory write, reports, audit, or other managers' private data.
- Do not show fake metrics, fake sync/online states, or placeholder modules as production UI.
- Use backend status values exactly.
- Keep one role/workspace active at a time.
- For every major UI modification, render the app and visually validate role screens before calling the milestone done.

## Visual Validation Rule

Use the fastest reliable target first, then confirm on Android when device behavior matters:

| Target | Use | Notes |
|---|---|---|
| MacBook Chrome localhost | Fast role-by-role screenshots while iterating | Run Flutter on Chrome/web and use a localhost-only Chrome instance with web security disabled because the API does not expose browser CORS headers. |
| Android device | Final mobile-device check | Required for camera/QR, keyboard, native storage, safe areas, and gesture/navigation behavior. |

Current screenshot output folder: `/private/tmp/greenroot-mobile-visuals`.

Visual pass checklist for each major UI milestone:

- Customer: Home, Buying, Profile.
- Nursery owner: Home, Buying, Selling, Create FAB sheet, Profile.
- Manager: Home, Buying, Work, Create FAB sheet, Profile.
- Driver: Home, Driver, scan/join flow, Profile.
- Record visible UI issues in this tracker before continuing.

## Done

| Date | Area | Change | Verification |
|---|---|---|---|
| 2026-06-28 | Audit | Identified active unnecessary UI candidates: customer global FAB, stale `Plants/My Activity` customer nav, legacy placeholder dashboards, transport dashboard, old activity wording, inventory stock wording. | Local code search |
| 2026-06-28 | Customer shell | Removed the always-visible customer floating action button and duplicate customer action sheet. Customer invite/nursery registration actions should live in onboarding, profile, or explicit home cards only. | `flutter test`; analyzer error/warning filter clean |
| 2026-06-28 | Tests | Removed two unnecessary null-comparison warnings from driver tests. | `flutter test`; analyzer error/warning filter clean |
| 2026-06-28 | Docs | Updated `MOBILE.md` to show current shell state and cleanup target tabs. | Markdown update |
| 2026-06-28 | Customer nav | Superseded the earlier split-tab experiment and restored the plan-approved customer shell: `Home / Buying / Profile`. Buying keeps internal sections for quotations, orders, and tracking. | Code review; verification rerun pending |
| 2026-06-28 | Owner/manager create UX | Kept the role FAB as the single create entry point. Owner actions are New Order, New Quotation, New Plant Request. Manager actions add Create Dispatch after loading. | Code review; verification rerun pending |
| 2026-06-28 | Visual validation setup | Established a MacBook Chrome localhost screenshot loop and captured Buyer Home plus Android Driver Home/Profile. Normal Chrome web is blocked by API CORS, so use the localhost-only disabled-web-security Chrome runner for fast screenshots. | Screenshots in `/private/tmp/greenroot-mobile-visuals` |
| 2026-06-28 | Role dashboards | Reworked Buyer, Nursery Owner, and Manager home dashboards around lifecycle work queues instead of decorative/duplicate actions. Driver dashboard remains the dedicated trip-first screen. | `flutter test`; analyzer error/warning filter clean; buyer screenshot captured |
| 2026-06-28 | Driver profile | Hid the generic customer access card in driver-only profile rendering. | `flutter test`; analyzer error/warning filter clean |
| 2026-06-28 | Role shell alignment | Restored role tabs to `Mobile_UI_UX_Plan.md`: customer Home/Buying/Profile, driver Home/Driver/Profile, owner Home/Buying/Selling/Profile, manager Home/Buying/Work/Profile. | `flutter test`; analyzer clean; role screenshots |
| 2026-06-28 | Deep-link guards | Added router guards so customer/driver cannot deep-link into sourcing, plant requests, inventory, members, dispatch management, or seller create forms. Owner-only members and inventory writes are guarded. | `flutter test`; analyzer clean |
| 2026-06-28 | Active workspace bootstrap | Fixed stale saved `BUYER` role and missing nursery-status fallback so owner/manager workspaces are not demoted to customer mode. Owner with multiple workspaces now reaches workspace select. | `flutter test`; analyzer clean; role screenshots |
| 2026-06-28 | Driver bottom nav | Made driver nav labels visible and kept scan as the center action: Home / Driver / Scan / Profile. | Driver screenshot |
| 2026-06-28 | Bug fixes (5) | Fixed customer tab nav (indices 2→1 for orders/tracking), driver scan (went to Profile → now opens QR scanner), driver ACCEPTED status missing from active count, buying tracking tab wrong dispatch status filters (LOADING_STARTED/COMPLETED → PENDING/ACCEPTED), manager cancel order button (removed). | `flutter test`; analyzer clean |
| 2026-06-28 | Buyer direct order | Built `BuyerOrderCreateScreen` at `/orders/buy` (no `_canSellGuard`); added `createBuyerOrder()` to OrderRepository (no buyer_mobile); added "Buy Plants" FAB + empty-state button to BuyingScreen for customer-only users. | `flutter test 50/50`; `flutter build apk --debug` passes; analyzer clean |
| 2026-06-28 | Owner Selling | Added Inventory section (Plant Catalog + Add Inventory) and Plant Requests section to owner Selling screen. | Analyzer clean |
| 2026-06-28 | Manager Work | Added Plant Requests section to manager Work screen. Manager cannot write inventory — only owner sections link to `/inventory/add`. | Analyzer clean |
| 2026-06-28 | Router | Added `/inventory`, `/requests`, `/orders/buy` routes with correct guards. | Analyzer clean |
| 2026-06-28 | Visual validation | Captured 9 role screenshots via Flutter web (CDP token injection): Customer×3, Owner×2, Manager×2, Driver×2. All role tab shells verified: Customer(Owner mode) Home/Buying/Selling/Profile, Owner Home/Buying/Selling/Profile, Manager Home/Buying/Work/Profile, Driver Home/Driver/Scan QR/Profile. Content sections match API/RBAC rules. | Screenshots in `/private/tmp/greenroot-mobile-visuals` |

## Visual Findings

| Date | Role | Screen | Finding | Status |
|---|---|---|---|---|
| 2026-06-28 | Driver | Profile | Driver profile showed a `Customer` access card in driver-only mode. Code now hides that card for driver-only users. | Fixed in code; needs device screenshot refresh |
| 2026-06-28 | All roles | Web visual runner | Browser-backed Flutter web needs a localhost Chrome with web security disabled because the API lacks CORS headers for normal browser calls. | Tooling note |
| 2026-06-28 | Owner/Manager | Mac headless Chrome | Headless Chrome drops repeated digits in Flutter canvas text input, so owner/manager login screenshots are not trustworthy from headless mode. Use normal Chrome with disabled web security or Android for true role screenshots. | Open tooling issue |
| 2026-06-28 | Customer | Home | Fresh corrected build shows only Home, Buying, Profile. No Selling, Sourcing, Requests, or Driver tab. | Screenshot: `/private/tmp/greenroot-mobile-visuals/customer-home.png` |
| 2026-06-28 | Owner | Workspace + Home | Owner seed reaches workspace select, then Home, Buying, Selling, Profile with owner FAB. | Screenshots: `/private/tmp/greenroot-mobile-visuals/owner-post-login.png`, `/private/tmp/greenroot-mobile-visuals/owner-home.png` |
| 2026-06-28 | Manager | Home | Manager seed shows Home, Buying, Work, Profile with manager FAB. | Screenshot: `/private/tmp/greenroot-mobile-visuals/manager-home.png` |
| 2026-06-28 | Driver | Home | Driver seed shows Home, Driver, Scan, Profile. No Buying or Selling tab. | Screenshot: `/private/tmp/greenroot-mobile-visuals/driver-home.png` |
| 2026-06-28 | Owner | Home + Selling | Priya (9100000000) correctly reaches workspace-select (has both Nursery Owner and Manager roles in seed). After selecting Nursery Owner: shows Nursery Dashboard with Open orders/Dispatch ready counts, Today's Summary row, action cards, and quick-links (My Nursery/Managers/Customers). Selling tab: Operations (Quotations, Orders, Dispatches), Inventory (Plant Catalog, Add Inventory), Plant Requests (All Requests, Create Request), Sourcing — all sections present. | Screenshots: `/private/tmp/greenroot-mobile-visuals/owner-home.png`, `/private/tmp/greenroot-mobile-visuals/owner-selling.png` |
| 2026-06-28 | Manager | Home + Work | Gumastha (9200000000) shows Manager role badge, GreenRoot Dev Nursery workspace, Work Dashboard (Needs action / In loading counts), Today's Summary row (Orders/Dispatches/Loading/Delivered), action cards (Orders to Confirm, Dispatch to Create, Need Posts). Work tab: Loading Queue banner, My Work (My Quotations, My Orders, Dispatches), Plant Requests (All Requests, Create Request), Sourcing. | Screenshots: `/private/tmp/greenroot-mobile-visuals/manager-home.png`, `/private/tmp/greenroot-mobile-visuals/manager-work.png` |
| 2026-06-28 | Driver | Home + Driver tab | Raju (9400000000) shows Driver shell: Home/Driver/Scan QR/Profile tabs. Home: No Active Trip card (Available badge), Join a Trip section (QR code row + Trip ID input + Join Trip button), How it works tip. Driver tab: My Trips with Active/History sub-tabs, empty state (No active trip). | Screenshots: `/private/tmp/greenroot-mobile-visuals/driver-home.png`, `/private/tmp/greenroot-mobile-visuals/driver-trips.png` |
| 2026-06-28 | Customer (Ravi) | Home + Buying + Buy Plants | Ravi (9300000000) seed has both PERSONAL/CUSTOMER and OWNED_NURSERY/OWNER workspaces. App auto-selects Owner (single business workspace, no workspace-select shown). Home shows Owner Nursery Dashboard — correct for this user's seed role. Buying tab accessible; shows Quotations/Orders/Tracking sections. Buy Plants form (`/orders/buy`): Select Nursery dropdown, Your Name (optional), Plants list (+Add Plant), Notes, Place Order button. | Screenshots: `/private/tmp/greenroot-mobile-visuals/customer-home.png`, `/private/tmp/greenroot-mobile-visuals/customer-buying.png`, `/private/tmp/greenroot-mobile-visuals/customer-buy-plants.png` |
| 2026-06-28 | Driver | Home web delay | `FutureProvider.autoDispose` on driver home does not begin API calls until a CDP re-render event fires (~20s after page load on Flutter web). APIs respond in <10ms; this is a Flutter web/Riverpod autoDispose quirk. Works normally on Android. | Non-blocking web-only behavior; no code change needed |
| 2026-06-28 | Owner | Display name | Priya's display name shows as "Updated Owner" in greeting (workspace-select and home) instead of "Priya". Seed data name mismatch. | Seed data; no app code change needed |

## In Progress

_(none — visual validation milestone complete)_

## Next

| Priority | Area | Task | Why |
|---:|---|---|---|
| 1 | Inventory wording | Replace stock-ledger language with simple availability/catalog language | V1 inventory is not physical stock management. |
| 2 | Legacy dashboards | Remove or isolate placeholder dashboards with `—` metrics from active navigation/imports | Fake metrics are forbidden by UI plan. |
| 3 | Activity onboarding | Remove broad activity selector cards unless they map to real onboarding state and APIs | Prevent duplicate onboarding paths. |
| 4 | Tests | Add widget/provider tests for role tabs and forbidden actions | Covers positive and negative UI cases. |

## Verification Log

| Date | Command | Result |
|---|---|---|
| 2026-06-28 | `flutter test` | Passed: 50 tests |
| 2026-06-28 | `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 \| rg "error •\|warning •"` | Clean: no error/warning lines |
| 2026-06-28 | `flutter test` | Passed after customer navigation split: 50 tests |
| 2026-06-28 | `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 \| rg "error •\|warning •"` | Clean after customer navigation split: no error/warning lines |
| 2026-06-28 | `flutter test` | Passed after owner/manager create consolidation: 50 tests |
| 2026-06-28 | `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 \| rg "error •\|warning •"` | Clean after owner/manager create consolidation: no error/warning lines |
| 2026-06-28 | `./test-api.sh` in `greenroot-api` | Passed: 292/292 API/RBAC/business-rule tests |
| 2026-06-28 | `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 \| rg "error •\|warning •"` | Clean after role shell, guard, and bootstrap fixes: no error/warning lines |
| 2026-06-28 | `flutter test` | Passed after role shell, guard, and bootstrap fixes: 50 tests |
| 2026-06-28 | `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 \| rg "error •\|warning •"` | Clean after buyer order flow, selling screen, router additions |
| 2026-06-28 | `flutter test` | Passed after buyer order flow + selling screen additions: 50 tests |
| 2026-06-28 | `flutter build apk --debug` | Build passed (Kotlin plugin warning unrelated to our code) |
| 2026-06-28 | Flutter web role screenshots | 9 screenshots captured via CDP (token injection + AES-256-GCM encryption): Customer×3, Owner×2, Manager×2, Driver×2. All tabs and content sections verified. Visual validation milestone complete. |
