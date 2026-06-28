# GreenRoot Mobile UI/UX Preview Plan — v2 (Corrected)

> Original draft: 2026-06-27  
> Corrected: 2026-06-27 — all errors reconciled against RBAC_NOTES.md, bussiness-rules.md, bussiness_rules2.md, and test-api.sh  
> Scope: Flutter mobile app only  
> Audience: product, backend, mobile, QA  
> Rule: The mobile app must show each user only the information and actions allowed by the latest API, database schema, business rules, and RBAC.

---

## 0. Corrections From v1 (Errors Found And Fixed)

| # | Where | Original Error | Correct Behaviour |
|---|---|---|---|
| 1 | §9 Customer, §13 Screen List | Customer can view delivery proof via `GET /api/v1/attachments` | RBAC: Customer = ❌ for ALL attachment operations. Delivery evidence is only accessible through dispatch tracking (`GET /dispatches/{id}/tracking/latest`) or public link (`GET /track/{uuid}`). "Delivery Proof" screen removed from customer. |
| 2 | §7 Manager Quick Actions | `PUT/DELETE /api/v1/orders/items/{itemId}` (missing order ID) | Correct path: `PUT/DELETE /api/v1/orders/{orderId}/items/{itemId}` |
| 3 | §13 Driver Screens | "drivers/me, driver update APIs" implies driver can edit own profile | RBAC: only Admin can `PUT /drivers/{id}`. Driver screen is **VIEW ONLY**. Driver CAN post location but cannot self-edit profile details. |
| 4 | §9 Customer — prohibited actions | "Create selling order — Not allowed" | `test-api.sh` confirms buyers CAN place orders (`POST /orders` returns 201). A customer buying flow (Browse → Request Quote or Direct Buy) must be included in mobile. |
| 5 | §6 Owner Quick Actions | "Invite manager/customer — Owner scope only" | RBAC: Manager can create `DRIVER_INVITE` and `CUSTOMER_INVITE`. Only `MANAGER_INVITE` is owner-exclusive. |
| 6 | §6 Owner, §7 Manager | Missing: Convert Quotation to Order | Both owner and manager can `POST /api/v1/quotations/{id}/convert-to-order` |
| 7 | §6 Owner, §7 Manager | Missing: Approve Quotation action | Both owner and manager can `POST /api/v1/quotations/{id}/approve` |
| 8 | §7 Manager Quick Actions | Missing: Create Dispatch | RBAC allows `POST /api/v1/dispatches` for managers |
| 9 | §7 Manager Quick Actions | Missing: Upload Loading Photos | RBAC §7: manager CAN upload loading photos via `POST /api/v1/attachments` |
| 10 | §6 Owner Quick Actions | Missing: Assign Manager to Order (loading responsibility) | `PUT /api/v1/orders/{id}/assign-manager` — Owner only |
| 11 | §6 Owner Quick Actions | Missing: Assign Driver to Order | `PUT /api/v1/orders/{id}/assign-driver` — Owner only |
| 12 | §6 Owner Quick Actions | Missing: Cancel Order | `POST /api/v1/orders/{id}/cancel` — Owner + Admin |
| 13 | §6 Owner Quick Actions | Missing: Delete Draft Quotation | `DELETE /api/v1/quotations/{id}` — Owner only, on draft only |
| 14 | §6 Owner Quick Actions | Missing: Generate Trip UUID/QR for dispatch | Owner-only per RBAC §8 |
| 15 | §6 Owner Quick Actions | Missing: Reopen Loading | Owner-only feature per RBAC §7 |
| 16 | §8 Driver Quick Actions | Missing: Reject Trip | RBAC §8: driver can reject unaccepted trips |
| 17 | §11 Status Mapping | Dispatch status list missing `ACCEPTED` | After driver accepts via `POST /dispatches/{id}/accept`, dispatch enters `ACCEPTED` state |
| 18 | §11 Status Mapping | Loading status listed as single value `LOADING` | API uses intermediate `LOADING_STARTED` → `LOADING_COMPLETED` per RBAC_NOTES §7 |
| 19 | §5 Navigation | Unified 5-tab shell is already built (Home/Buying/Selling/Driver/Profile) | Role navigation in plan now describes CONTENT rendered in each tab, not separate tab sets per role |
| 20 | §7 Manager Quick Actions | Missing: Approve Quotation, Convert to Order | Both allowed for manager per RBAC §5 |

---

## 1. Source Of Truth

| Source | What It Controls |
|---|---|
| `greenroot-api/bussiness-rules.md` | Core GreenRoot V1 business rules |
| `greenroot-api/bussiness_rules2.md` | Plant Sourcing Network rules |
| `greenroot-api/RBAC_NOTES.md` | Role permissions and mobile mapping |
| `greenroot-api/API.md` | Latest registered API routes and module inventory |
| `greenroot-api/DB.md` | Latest DB table inventory and schema rules |
| `greenroot-api/test-api.sh` | Expected RBAC behaviour and negative tests — **tie-breaker when RBAC_NOTES and business rules conflict** |
| `greenroot-mobile/MOBILE.md` | Current mobile architecture and existing screen inventory |

Current backend facts:

| Item | Value |
|---|---:|
| Application DB tables | 54 |
| Registered APIs | 181 |
| Mobile target roles | Nursery Owner, Manager, Driver, Customer |

> **Tie-break rule:** When RBAC_NOTES.md and bussiness-rules.md disagree, `test-api.sh` is the final authority on what the current API actually enforces.  
> Example: RBAC table says Customer = ❌ for `POST /orders`, but `test-api.sh` expects HTTP 201 for buyer order creation. Mobile must allow buyer order placement.

Super Admin/Admin is not a mobile operating role. If an admin logs in, show a single "Admin is managed in the web portal" screen with no business transaction UI.

---

## 2. Core Mobile Rule

The app must be role-first, not feature-first.

After login, the user sees only:

1. Their own data.
2. Their current workspace data.
3. Actions permitted by RBAC.
4. Screens backed by current APIs.

The app must never show:

1. Placeholder metrics not API-backed.
2. Fake status toggles (Online, On Duty, Sync Now) — no API exists.
3. Admin-only modules.
4. Reports or audit logs for roles where API/RBAC returns `403`.
5. Customer private data to managers or drivers.
6. Nursery operations to customers or drivers.
7. Plant sourcing network to drivers or customers.

When business rules and current API/RBAC conflict, follow the current API/RBAC and call out the gap.

---

## 3. Role Detection And Session Flow

### Auth Flow

```
Splash
  → token refresh + GET /users/me + GET /me/workspaces
  → Login (if not authenticated)
  → OTP Verify
  → Create Profile (if profile is incomplete)
  → Admin Wall (if user is ADMIN/SUPER_ADMIN — no mobile business UI)
  → Workspace Select (if user has multiple usable workspace types)
  → MainShell (role-appropriate tabs visible)
```

### Required APIs

| Purpose | API |
|---|---|
| Send OTP | `POST /api/v1/auth/send-otp` |
| Verify OTP | `POST /api/v1/auth/verify-otp` |
| Refresh token | `POST /api/v1/auth/refresh-token` |
| Logout | `POST /api/v1/auth/logout` |
| Current user | `GET /api/v1/users/me` |
| Workspaces | `GET /api/v1/me/workspaces` |

### Workspace Rules

| Workspace Type | Capability Flags | Active Tab Set |
|---|---|---|
| `OWNED_NURSERY` | `isNurseryOwner=true`, `canSell=true` | Home + Buying + Selling(owner) + Profile |
| `MANAGER_NURSERY` | `isManager=true`, `canSell=true` | Home + Buying + Selling(manager) + Profile |
| `DRIVER` | `hasDriverProfile=true` | Home + Driver + Profile |
| Personal / buyer account only | all false | Home + Buying + Profile |

If a user has multiple valid workspace types (e.g. Owner + Driver), the app shows all relevant tabs and uses the active workspace context to scope data fetching.

---

## 4. Global UX Principles

1. One role, one clear home. Each role sees only its operational context.
2. Unified 5-tab shell — tabs are hidden, not shown as empty, when role has no access.
3. Use real counts only after API response. Skeleton rows until data loads.
4. Empty states explain the next valid action for that role.
5. Disable or hide actions that would return `403`.
6. Never expose private details even if present in an API payload (e.g. manager cannot see customer mobile on an order detail screen).
7. All destructive actions need confirmation. Cancellations need a reason field where the API expects it.
8. Each card answers one operational question.
9. Loading states use skeletons, never static fake data.
10. Error states show retry and a short reason.
11. Status values displayed in UI must match backend enum values exactly — do not invent human labels that diverge from the stored value.

---

## 5. Current App Navigation (Unified Shell)

The app already implements a unified 5-tab `MainShell`. Content within each tab is capability-rendered based on `UserCapabilities`.

| Tab | Icon | Who Sees It | Content |
|---|---|---|---|
| Home | house | All roles | Role-specific greeting, action cards, and counts |
| Buying | cart | Owner, Manager, Customer | Quotations received, own orders, delivery tracking |
| Selling | storefront | Owner, Manager only | Owner: full sales ops. Manager: assigned loading queue |
| Driver | truck | Driver only | Active trip, trip history, scan code |
| Profile | person | All roles | Profile info, addresses, active sessions, sign out |

Navigation rules:
- Customer without nursery or driver profile: sees Home + Buying + Profile (Selling and Driver tabs hidden).
- Driver without selling capability: sees Home + Driver + Profile (Buying and Selling tabs hidden).
- Owner also operating as driver: all 5 tabs visible.
- Admin: no tabs, redirect to Admin Wall screen.

---

## 6. Nursery Owner Experience

### Owner Home Tab

**Goal:** Compact operational control view of the owner's own nursery.

Allowed API data:

| UI Block | API | DB Tables |
|---|---|---|
| Nursery identity and status | `GET /api/v1/nurseries/owned` | `nurseries` |
| Owner dashboard counts | `GET /api/v1/me/owner-dashboard` | `orders`, `quotations`, `nurseries` |
| Active orders summary | `GET /api/v1/orders` (nursery scope) | `orders`, `order_items` |
| Loading queue summary | `GET /api/v1/orders` filtered by loading status | `orders` |
| Active dispatches summary | `GET /api/v1/dispatches` (nursery scope) | `dispatches`, `dispatch_items` |
| Open plant requests | `GET /api/v1/plant-requests` | `plant_requests` |
| Notifications badge | `GET /api/v1/notifications` | `notifications` |

Owner Home cards (show only if count > 0 after API response):

| Card | Show When | Tap Action |
|---|---|---|
| Orders needing action | Orders in `PENDING` or `CONFIRMED` status | Open Selling tab → Orders list |
| Loading in progress | Orders in `LOADING_STARTED` status | Open Selling tab → Loading queue |
| Active dispatches | Dispatches in `DISPATCHED` or `IN_TRANSIT` | Open Selling tab → Dispatches list |
| Open plant requests | Requests in `OPEN` status | Open Requests screen |
| Sourcing activity | Owner is sourcing network member | Open Sourcing screen |
| Pending invites | Invites in `PENDING` status | Open Members screen |

Owner FAB quick actions (floating action button menu):

| Action | API | Notes |
|---|---|---|
| New Order | `POST /api/v1/orders` | Direct order (no quotation) |
| New Quotation | `POST /api/v1/quotations` | Internal or customer type |
| New Plant Request | `POST /api/v1/plant-requests` | Owner/manager only |

### Owner — Selling Tab (Full Operations)

The Selling tab for an owner shows a sub-navigation with sections:

**A. Orders**

| Action | API | Guard |
|---|---|---|
| List orders | `GET /api/v1/orders` | Owner scope, server-filtered |
| View order detail | `GET /api/v1/orders/{id}` | Own nursery |
| Create order | `POST /api/v1/orders` | Owner or manager |
| Assign manager (loading) | `PUT /api/v1/orders/{id}/assign-manager` | **Owner only** |
| Assign driver | `PUT /api/v1/orders/{id}/assign-driver` | **Owner only** |
| Start loading | `POST /api/v1/orders/{id}/start-loading` | Owner or assigned manager |
| Upload loading photos | `POST /api/v1/attachments` (entity=ORDER) | Owner or assigned manager |
| Add item during loading | `POST /api/v1/orders/{id}/items` | While status = `LOADING_STARTED` only |
| Update item during loading | `PUT /api/v1/orders/{id}/items/{itemId}` | While status = `LOADING_STARTED` only |
| Remove item during loading | `DELETE /api/v1/orders/{id}/items/{itemId}` | While status = `LOADING_STARTED` only |
| Complete loading | `POST /api/v1/orders/{id}/complete-loading` | Owner or assigned manager |
| Reopen loading | API endpoint TBD | **Owner only** — hide if not available |
| Cancel order | `POST /api/v1/orders/{id}/cancel` | **Owner only**, requires reason field |
| View order payments | `GET /api/v1/orders/{id}/payments` | Owner only |

Items add/update/remove: **Only show while order is in `LOADING_STARTED` status.** Hide all edit buttons once `LOADING_COMPLETED`.

**B. Quotations**

| Action | API | Guard |
|---|---|---|
| List quotations | `GET /api/v1/quotations` | Owner nursery scope |
| View quotation | `GET /api/v1/quotations/{id}` | Own nursery |
| Create internal quotation | `POST /api/v1/quotations` (type=INTERNAL) | Owner or manager |
| Create customer quotation | `POST /api/v1/quotations` (type=CUSTOMER, recipient required) | Owner or manager |
| Approve quotation | `POST /api/v1/quotations/{id}/approve` | Owner or manager |
| Convert to order | `POST /api/v1/quotations/{id}/convert-to-order` | Owner or manager |
| Assign manager to quotation | `POST /api/v1/quotations/{id}/assign-manager` | **Owner only** |
| Delete draft quotation | `DELETE /api/v1/quotations/{id}` | **Owner only**, draft status only |

Never show Delete on completed/approved quotations — business rule: completed quotations are read-only and cannot be deleted.

**C. Dispatches**

| Action | API | Guard |
|---|---|---|
| List dispatches | `GET /api/v1/dispatches` | Own nursery scope |
| View dispatch | `GET /api/v1/dispatches/{id}` | Own nursery |
| Create dispatch | `POST /api/v1/dispatches` | Owner or manager, after loading complete |
| Generate Trip UUID/QR | Embedded in dispatch create or `GET /dispatches/{id}` | **Owner only** |
| Update dispatch status | `PUT /api/v1/dispatches/{id}/status` | Owner or manager |
| Add dispatch item | `POST /api/v1/dispatches/{id}/items` | Owner or manager |
| View live driver location | `GET /api/v1/dispatches/{id}/tracking/latest` | Owner (own nursery) |

**D. Plant Requests**

| Action | API | Guard |
|---|---|---|
| List plant requests | `GET /api/v1/plant-requests` | Nursery scope |
| View request | `GET /api/v1/plant-requests/{id}` | Own nursery |
| Create request | `POST /api/v1/plant-requests` | Owner or manager |
| Update request | `PUT /api/v1/plant-requests/{id}` | Own nursery |
| Update request status | `PUT /api/v1/plant-requests/{id}/status` | Own nursery |
| List responses | `GET /api/v1/plant-requests/{id}/responses` | Own nursery |
| Accept/reject response | `PUT /api/v1/plant-requests/responses/{responseId}` | Request owner only |

**E. Sourcing Network (Network section)**

| Action | API | Guard |
|---|---|---|
| View membership | `GET /api/v1/nurseries/{id}/sourcing-membership` | Owner or manager |
| Join network | `POST /api/v1/nurseries/{id}/sourcing-membership` | Owner or manager |
| Leave network | `DELETE /api/v1/nurseries/{id}/sourcing-membership` | Owner or manager |
| Discover nearby nurseries | `GET /api/v1/sourcing-network/nurseries` | Owner or manager |
| View nursery sourcing profile | `GET /api/v1/sourcing-network/nurseries/{nurseryId}` | Owner or manager |
| List featured plants | `GET /api/v1/nurseries/{id}/featured-plants` | Owner or manager |
| Add featured plant | `POST /api/v1/nurseries/{id}/featured-plants` | Owner or manager |
| Update featured plant | `PUT /api/v1/nurseries/{id}/featured-plants/{id}` | Owner or manager |
| Remove featured plant | `DELETE /api/v1/nurseries/{id}/featured-plants/{id}` | Owner or manager |
| List sourcing posts | `GET /api/v1/sourcing-posts` | Owner or manager |
| Create sourcing post | `POST /api/v1/sourcing-posts` | Owner or manager |
| Update own post | `PUT /api/v1/sourcing-posts/{id}` | Post creator |
| Delete own post | `DELETE /api/v1/sourcing-posts/{id}` | Post creator |
| View post responses | `GET /api/v1/sourcing-posts/{id}/responses` | Owner or manager |
| Respond to another nursery's post | `POST /api/v1/sourcing-posts/{id}/responses` | Different nursery only |
| Accept/decline a response | `PUT /api/v1/sourcing-posts/{id}/responses/{responseId}` | Post owner only |

**F. Inventory**

| Action | API | Guard |
|---|---|---|
| List inventory | `GET /api/v1/nurseries/{id}/inventory` | Own nursery only |
| View item | `GET /api/v1/inventory/{id}` | Own nursery only |
| Add entry | `POST /api/v1/inventory` | **Owner only** (manager view-only) |
| Update quantity | `PUT /api/v1/inventory/{id}` | **Owner only** |

**G. Members Management**

| Action | API | Guard |
|---|---|---|
| List managers | `GET /api/v1/nurseries/{id}/managers` | **Owner only** |
| Remove manager | `DELETE /api/v1/nurseries/{id}/managers/{userId}` | **Owner only** |
| Create Manager invite | `POST /api/v1/invites` (type=MANAGER_INVITE) | **Owner only** |
| Create Customer invite | `POST /api/v1/invites` (type=CUSTOMER_INVITE) | Owner or manager |
| Create Driver invite | `POST /api/v1/invites` (type=DRIVER_INVITE) | Owner or manager |
| List nursery invites | `GET /api/v1/nurseries/{id}/invites` | **Owner only** |
| Cancel invite | `POST /api/v1/invites/{uuid}/cancel` | Own created invites |
| Connect driver to nursery | `POST /api/v1/nurseries/{id}/drivers` | Owner or manager |
| Approve driver connection | `POST /api/v1/nurseries/{id}/drivers/{driverUserId}/approve` | **Owner only** |
| List connected drivers | `GET /api/v1/nurseries/{id}/drivers` | Owner or manager |

### Owner — Buying Tab

Owner may also be a buyer (purchasing from other nurseries). Buying tab shows the standard customer experience for the owner's personal buying activity — same as Customer Buying experience documented in §9.

### Owner — Profile Tab

| Action | API |
|---|---|
| View own profile | `GET /api/v1/users/me` |
| Edit own profile | `PUT /api/v1/users/me` |
| View and edit nursery profile | `GET/PUT /api/v1/nurseries/{id}` |
| Manage own addresses | `GET/POST/PUT/DELETE /api/v1/users/{id}/addresses` |
| View own subscription | `GET /api/v1/subscriptions/me` |
| Active sessions | `GET /api/v1/users/{id}/sessions` |
| Logout | `POST /api/v1/auth/logout` |

### Owner Must Never See

| Hidden UI | Reason |
|---|---|
| Admin dashboard | Admin-only |
| Platform plant create/edit | Admin-only |
| Global users table | Admin-only |
| Audit logs | Current API returns `403` for owner even though business rules permit it — hide until API support is confirmed |
| Revenue-level reports | No owner report API except owner dashboard endpoint |
| Other nurseries' private data | Absolute privacy between nurseries |
| Delete completed orders | Business rule violation — orders are permanent records |
| Delete completed quotations | Business rule violation |
| Edit order items after `LOADING_COMPLETED` | Order is locked — hide all item edit buttons |

---

## 7. Manager Experience

### Manager Home Tab

**Goal:** Show only operational work assigned to this manager. Manager must never see owner-level controls or other managers' work.

Allowed API data:

| UI Block | API | DB Tables |
|---|---|---|
| Managed nursery workspace | `GET /api/v1/me/workspaces` | `nursery_users`, `nurseries` |
| Assigned orders | `GET /api/v1/orders` (server-scoped to manager) | `orders` |
| Assigned quotations | `GET /api/v1/quotations` (server-scoped to manager) | `quotations` |
| Loading queue | `GET /api/v1/orders` (assigned, loading status) | `orders`, `order_items` |
| Dispatches | `GET /api/v1/dispatches` (nursery scope) | `dispatches` |
| Plant requests | `GET /api/v1/plant-requests` | `plant_requests` |

Manager Home cards:

| Card | Show When | Tap Action |
|---|---|---|
| Orders assigned to me | Assigned orders exist | Open Selling tab → Work queue |
| Loading tasks | Assigned orders in loading status | Open Loading queue |
| Dispatch tasks | Dispatches need action | Open Dispatch detail |
| Open plant requests | Requests exist | Open Requests screen |
| Sourcing activity | Sourcing posts or responses pending | Open Sourcing screen |

### Manager — Selling Tab (Assigned Work Queue)

Manager's Selling tab shows only work assigned to them. Content is server-scoped by the API — the manager cannot manually filter to see another manager's orders.

**A. Orders (Assigned Only)**

| Action | API | Guard |
|---|---|---|
| List assigned orders | `GET /api/v1/orders` | Server returns assigned-only |
| View order detail | `GET /api/v1/orders/{id}` | Assigned order only |
| Create order | `POST /api/v1/orders` | Manager allowed |
| Start loading | `POST /api/v1/orders/{id}/start-loading` | **Assigned order only** |
| Upload loading photos | `POST /api/v1/attachments` (entity=ORDER) | Assigned order + loading status |
| Add item during loading | `POST /api/v1/orders/{id}/items` | While `LOADING_STARTED` only |
| Update item during loading | `PUT /api/v1/orders/{id}/items/{itemId}` | While `LOADING_STARTED` only |
| Remove item during loading | `DELETE /api/v1/orders/{id}/items/{itemId}` | While `LOADING_STARTED` only |
| Complete loading | `POST /api/v1/orders/{id}/complete-loading` | **Assigned order only** |

**B. Quotations (Assigned Only)**

| Action | API | Guard |
|---|---|---|
| List quotations | `GET /api/v1/quotations` | Server returns assigned-only |
| View quotation | `GET /api/v1/quotations/{id}` | Assigned only |
| Create quotation | `POST /api/v1/quotations` | Manager allowed |
| Approve quotation | `POST /api/v1/quotations/{id}/approve` | Manager allowed |
| Convert to order | `POST /api/v1/quotations/{id}/convert-to-order` | Manager allowed |

**C. Dispatches**

| Action | API | Guard |
|---|---|---|
| List dispatches | `GET /api/v1/dispatches` | Nursery scope, assigned |
| View dispatch | `GET /api/v1/dispatches/{id}` | Own nursery |
| **Create dispatch** | `POST /api/v1/dispatches` | Manager allowed per RBAC |
| Update dispatch status | `PUT /api/v1/dispatches/{id}/status` | Own nursery |
| Add dispatch item | `POST /api/v1/dispatches/{id}/items` | Own nursery |
| View live driver location | `GET /api/v1/dispatches/{id}/tracking/latest` | Assigned dispatches |

**D. Plant Requests**

| Action | API | Guard |
|---|---|---|
| List requests | `GET /api/v1/plant-requests` | Nursery scope |
| View request | `GET /api/v1/plant-requests/{id}` | Own nursery |
| Create request | `POST /api/v1/plant-requests` | Manager allowed |
| Update request | `PUT /api/v1/plant-requests/{id}` | Own nursery |

**E. Sourcing Network**

Manager has full sourcing access (same as owner for all sourcing endpoints). See §6-E for full action list. Manager can:
- Discover nearby nurseries
- Join/leave network on behalf of nursery
- Add/update/remove featured plants for own nursery
- Create NEED and AVAILABLE posts
- Respond to other nurseries' posts
- Create DRIVER_INVITE and CUSTOMER_INVITE (but NOT MANAGER_INVITE)

**F. Inventory (View Only)**

| Action | API | Note |
|---|---|---|
| List inventory | `GET /api/v1/nurseries/{id}/inventory` | View only |
| View item | `GET /api/v1/inventory/{id}` | View only |

Manager **cannot** create, update, or delete inventory entries. Hide all write controls.

### Manager Must Never See

| Hidden UI | Reason |
|---|---|
| Owner dashboard | API returns `403` |
| Nursery edit / status change | Owner/admin only |
| Customer mobile number | Business rule: manager cannot view |
| Customer address | Business rule: manager cannot view |
| Other managers' orders | Server scopes to assigned-only |
| Delete / cancel order | Manager prohibited |
| Delete quotation | Owner only |
| Assign manager to order | Owner only |
| Assign driver to order | Owner only |
| Reopen loading | Owner only |
| Generate Trip UUID/QR | Owner only |
| MANAGER_INVITE creation | Owner only |
| Managers list | Owner only |
| Nursery invites list | Owner only |
| Reports | Manager prohibited |
| Audit logs | Manager prohibited |
| Inventory write controls | Owner only |

---

## 8. Driver Experience

### Driver Home Tab

**Goal:** Let the driver focus on one active trip. No nursery, order, quotation, or sourcing content is ever shown.

Allowed API data:

| UI Block | API | DB Tables |
|---|---|---|
| Driver profile | `GET /api/v1/drivers/me` | `drivers` |
| All assigned trips | `GET /api/v1/dispatches` (driver scope) | `dispatches` |
| Trip detail | `GET /api/v1/dispatches/{id}` | `dispatches`, `dispatch_items` |
| Trip by code/QR | `GET /api/v1/dispatches/code/{code}` | `dispatches`, `dispatch_assignments` |
| Notifications | `GET /api/v1/notifications` | `notifications` |

Driver Home cards:

| Card | Show When | Tap Action |
|---|---|---|
| Current active trip | One trip in `ACCEPTED` or `IN_TRANSIT` | Open Trip Detail |
| Pending trip preview | Driver scanned a code, not yet accepted | Accept / Reject screen |
| Scan / Enter code | Always visible if no active trip | Open Scan screen |
| Trip history | Past `DELIVERED`/`CANCELLED` trips exist | Open Trips list |

### Driver Quick Actions (Correct API Endpoints)

| Action | API | Notes |
|---|---|---|
| Scan / enter trip code | `GET /api/v1/dispatches/code/{code}` | Preview before accept/reject |
| **Accept** trip | `POST /api/v1/dispatches/{id}/accept` | Driver only — sets dispatch to `ACCEPTED` |
| **Reject** trip | No explicit reject endpoint — driver does not accept, dispatch stays `PENDING` for reassignment | Show "Decline" UI; if API adds reject endpoint, use it |
| Post GPS location (background) | `POST /api/v1/tracking` | Background service when trip is `IN_TRANSIT` |
| Post GPS (alternative) | `POST /api/v1/drivers/{id}/location` | Same driver_locations table — use whichever API endpoint the backend exposes |
| Add trip event | `POST /api/v1/dispatches/{id}/trip-events` | Driver or admin only — owner/manager get `403` |
| Upload delivery proof | `POST /api/v1/attachments` (entity=DISPATCH) | Driver only — attach to dispatch |
| Complete delivery | `PUT /api/v1/dispatches/{id}/status` (status=DELIVERED) | Assigned driver only |

### Driver — Driver Tab

The Driver tab is the operational home for trip management:

```
Driver Tab
├── Active Trip Card (if trip is ACCEPTED / IN_TRANSIT)
│   ├── Destination address
│   ├── Order summary (no customer private details)
│   ├── Current status badge
│   └── Actions: [Update Event] [Upload Proof] [Complete Delivery]
├── Scan Trip Code (if no active trip)
│   └── QR scanner → calls GET /dispatches/code/{code} → preview screen
└── Trip History
    └── Delivered / Cancelled trips sorted by date
```

### Driver — Trip Detail Screen

| Data shown | Source |
|---|---|
| Dispatch status | `dispatch.status` |
| Dispatch items (plants, quantities) | `GET /dispatches/{id}` items |
| Destination address | `dispatch.destination_address` |
| Dispatch code | `dispatch.code` |
| Trip events log | `dispatch.trip_events` |

**Never show on trip detail:**
- Customer name, mobile, or home address
- Order financial totals
- Nursery internal notes

### Driver — Profile Tab

| Action | API | Notes |
|---|---|---|
| View own driver profile | `GET /api/v1/drivers/me` | **View only** |
| View own user profile | `GET /api/v1/users/me` | Read |
| Edit own user profile (name, etc.) | `PUT /api/v1/users/me` | Allowed |
| View active sessions | `GET /api/v1/users/{id}/sessions` | Read |
| Logout | `POST /api/v1/auth/logout` | |

> **IMPORTANT:** Driver cannot edit their driver profile details (license, vehicle type) via mobile. Only Admin can `PUT /api/v1/drivers/{id}`. Do not show an "Edit Driver Profile" button. The driver profile screen is READ ONLY. If driver details need updating, direct driver to contact admin.

### Driver Must Never See

| Hidden UI | Reason |
|---|---|
| Orders list or create | Driver has no order access |
| Quotations | Driver has no quotation access |
| Plant requests | Driver has no plant request access |
| Sourcing network | API returns `403` |
| Customer details | Privacy rule |
| Nursery ownership / member list | Driver is independent |
| Inventory | No access |
| Reports / audit | Not allowed |
| Plant catalogue | Driver = ❌ for all plant read endpoints |
| Edit driver profile button | Only Admin can update driver record |

---

## 9. Customer Experience

### Customer Home Tab

**Goal:** Help the customer track quotations, orders, and deliveries. Never expose nursery internal operations.

Allowed API data:

| UI Block | API | DB Tables |
|---|---|---|
| Received quotations | `GET /api/v1/quotations?buying=true` | `quotations`, `quotation_items` |
| Own orders | `GET /api/v1/orders?buying=true` | `orders`, `order_items` |
| Delivery tracking | `GET /api/v1/dispatches/{id}/tracking/latest` | `driver_locations` |
| Public tracking (no auth needed) | `GET /api/v1/track/{uuid}` | `trip_tracking_links` |
| Plant catalogue browse | `GET /api/v1/plants`, `GET /api/v1/plants/{id}` | `plants`, `plant_names`, `plant_images` |
| Invite accept | `GET /api/v1/invites/{uuid}`, `POST /api/v1/invites/{uuid}/accept` | `invites` |

Customer Home cards:

| Card | Show When | Tap Action |
|---|---|---|
| Quotations awaiting response | Quote in customer-action-required status | Quotation detail → Accept/Reject |
| Approved quotations | Approved quote exists | View quote detail |
| Active orders | Order in progress | View order detail |
| Delivery in progress | Dispatch tracking link available | Open Tracking tab |
| Register nursery | Always available (eligible customer can become owner) | Start nursery registration |
| Accept an invite | Customer has a UUID/QR code | Open invite accept screen |

### Customer — Buying Tab

Sub-sections within the Buying tab:

**A. Quotations Received**

| Action | API | Guard |
|---|---|---|
| List own quotations | `GET /api/v1/quotations?buying=true` | Own received only |
| View quotation detail | `GET /api/v1/quotations/{id}` | Own only |
| **Accept quotation** | `POST /api/v1/quotations/{id}/buyer-accept` | Customer only |
| **Reject quotation** | `POST /api/v1/quotations/{id}/buyer-reject` | Customer only |

**B. Orders (Buying)**

| Action | API | Guard |
|---|---|---|
| List own orders | `GET /api/v1/orders?buying=true` | Own received only |
| View order detail | `GET /api/v1/orders/{id}` | Own only — customer sees order status, items, totals, but NOT nursery internal notes |
| **Place a direct order** | `POST /api/v1/orders` | Confirmed by `test-api.sh` — buyers can create orders (HTTP 201). Include "Buy Plants" flow. |
| View order payments | `GET /api/v1/orders/{id}/payments` | Own order only |

> **Note on `POST /orders` for Buyers:** `test-api.sh` section 6 confirms HTTP 201 for buyers. The mobile "Buy Plants" flow should allow customers to create a direct purchase order from a nursery they are linked to. This is separate from the nursery's "create selling order" internal flow.

**C. Delivery Tracking**

| Action | API | Guard |
|---|---|---|
| View dispatch tracking live | `GET /api/v1/dispatches/{id}/tracking/latest` | Own order's dispatch |
| View public tracking link | `GET /api/v1/track/{uuid}` | No auth needed |

> **IMPORTANT:** Customer CANNOT access `GET /api/v1/attachments` — RBAC returns ❌ for all customer attachment operations. Do not show a "Delivery Proof" screen that calls the attachments API. Delivery evidence is communicated via dispatch status and tracking only.

**D. Plant Catalogue (Browse Only)**

| Action | API | Notes |
|---|---|---|
| Browse plants | `GET /api/v1/plants` | Read only |
| View plant detail | `GET /api/v1/plants/{id}` | Care guide, sizes, images |
| View care guide | `GET /api/v1/plants/{id}/care-guide` | Read only |

Customer cannot create, update, or delete plant entries — admin only.

### Customer — Profile Tab

| Action | API |
|---|---|
| View own profile | `GET /api/v1/users/me` |
| Edit own profile | `PUT /api/v1/users/me` |
| Manage own addresses | `GET/POST/PUT/DELETE /api/v1/users/{id}/addresses` |
| Active sessions | `GET /api/v1/users/{id}/sessions` |
| Register nursery (become owner) | `POST /api/v1/nurseries` |
| Logout | `POST /api/v1/auth/logout` |

### Customer Must Never See

| Hidden UI | Reason |
|---|---|
| Create selling order as nursery | Customer can place a buying order but cannot operate as a selling nursery |
| Create / edit quotations | Not allowed |
| Internal loading workflow | Nursery internal operation |
| Manager details | Private nursery operation |
| Driver private details | Private user data |
| Plant sourcing network | API returns `403` |
| Nursery reports / audit | Not allowed |
| Inventory management | Not allowed |
| **Delivery proof via `/attachments`** | **RBAC: customer = ❌ for all attachment operations** |
| Other customers' data | Absolute privacy |

---

## 10. Plant Sourcing Network UX

Available only to Nursery Owner and Manager. Customer and Driver get `403`.

**Business Rule:** This is a private B2B discovery network. It is NOT a marketplace and NOT inventory management. Featured plants are not guaranteed stock.

### Network Tab Content (Owner and Manager only)

```
Sourcing Tab
├── My Network Status (member / not member)
├── Nearby Nurseries (GET /sourcing-network/nurseries)
│   ├── Search bar (filter by plant name)
│   └── Nursery card: name, village, distance, road/lorry accessible, top plants
├── My Posts (NEED / AVAILABLE)
│   ├── List: GET /sourcing-posts?nursery_id=own
│   └── Responses received on own posts
└── Respond To Posts (from other nurseries)
```

### Sourcing Nursery Profile — Data to Show

| Data | Source |
|---|---|
| Nursery name | `sourcing_network.nursery_name` |
| Village / location | `nurseries.address` |
| Distance | Calculated or API-provided |
| Road accessibility | `sourcing_network_members.road_accessible` |
| Lorry accessible | `sourcing_network_members.lorry_accessible` |
| Top available plants | `GET /nurseries/{id}/featured-plants` |
| Contact number | `sourcing_network_members.contact_visible` — only if flag is true |

### Sourcing Nursery Profile — Never Show

| Data | Reason |
|---|---|
| Customers | Private |
| Orders | Private |
| Quotations | Private |
| Managers | Private |
| Financial information | Private |
| Exact inventory guarantee | Featured plants are NOT inventory — show disclaimer |

### Sourcing Post Types and Status

```
post_type: NEED | AVAILABLE
urgency:   TODAY | URGENT | FLEXIBLE
status:    OPEN | (closed/resolved as returned by API)
```

**Nursery cannot respond to its own post** — validate before showing "Respond" button.

---

## 11. Status Mapping (Exact API Values)

Always use backend enum values in UI status badges. Do not invent display labels that diverge from stored values.

### Orders

```
PENDING
CONFIRMED
LOADING_STARTED       ← loading in progress (start-loading endpoint called)
LOADING_COMPLETED     ← loading done, order locked
PARTIALLY_FULFILLED
COMPLETED
DELIVERED
CANCELLED
```

Business meaning:

| Business State | API Status | API Endpoint |
|---|---|---|
| Order created | `PENDING` | `POST /orders` |
| Order confirmed | `CONFIRMED` | `PUT /orders/{id}/status` |
| Loading started | `LOADING_STARTED` | `POST /orders/{id}/start-loading` |
| Items editable | While `LOADING_STARTED` | `POST/PUT/DELETE /orders/{id}/items/{itemId}` |
| Loading complete, order locked | `LOADING_COMPLETED` | `POST /orders/{id}/complete-loading` |
| Cancelled | `CANCELLED` | `POST /orders/{id}/cancel` |

> Do not use `LOADING` as a single status value. The API uses `LOADING_STARTED` and `LOADING_COMPLETED` as distinct states.

### Dispatches

```
PENDING       ← dispatch created, driver not yet accepted
ACCEPTED      ← driver accepted via POST /dispatches/{id}/accept
DISPATCHED    ← nursery marked dispatched
IN_TRANSIT    ← GPS tracking active
DELIVERED     ← driver completed delivery
CANCELLED
```

> `ACCEPTED` was missing from v1 plan. It is the state after `POST /dispatches/{id}/accept` returns 200. Driver trip workflow starts here.

### Plant Requests

```
DRAFT
OPEN
PARTIALLY_ACCEPTED
ACCEPTED
REJECTED
CLOSED
```

### Sourcing Posts

```
post_type: NEED | AVAILABLE
urgency:   TODAY | URGENT | FLEXIBLE
status:    OPEN | (closed/resolved states as returned by API)
```

---

## 12. Module Visibility Matrix

| Module | Owner | Manager | Driver | Customer |
|---|:---:|:---:|:---:|:---:|
| Auth / session | ✅ | ✅ | ✅ | ✅ |
| Workspace select | ✅ | ✅ | ✅ | ✅ |
| Plant catalogue (read-only) | ✅ | ✅ | ❌ | ✅ |
| Nursery profile (own) | ✅ manage | ✅ view | ❌ | ❌ |
| Nursery registration | ✅ (already owner) | ❌ | ❌ | ✅ → becomes owner |
| Members / managers list | ✅ owner only | ❌ | ❌ | ❌ |
| Customer relationships / invites | ✅ create MANAGER+DRIVER+CUSTOMER invite | ✅ create DRIVER+CUSTOMER invite only | ❌ | ✅ own invite accept only |
| Inventory | ✅ manage | ✅ view only | ❌ | ❌ |
| Quotations | ✅ create/manage own nursery | ✅ create/manage assigned | ❌ | ✅ own received (accept/reject only) |
| Orders | ✅ create/manage own nursery | ✅ create/manage assigned | ❌ | ✅ own buying (create + view) |
| Loading workflow | ✅ own nursery | ✅ assigned orders only | ❌ | ❌ |
| Dispatch create | ✅ | ✅ | ❌ | ❌ |
| Dispatch view | ✅ own nursery | ✅ own nursery / assigned | ✅ assigned only | ✅ own order's dispatch |
| Tracking (post GPS) | ❌ | ❌ | ✅ own active trip | ❌ |
| Tracking (view) | ✅ own dispatches | ✅ assigned/own nursery | ✅ own trip | ✅ own delivery |
| Plant requests | ✅ | ✅ | ❌ | ❌ |
| Sourcing network | ✅ | ✅ | ❌ | ❌ |
| Payments | ✅ own nursery only | ❌ | ❌ | ✅ own order-linked only |
| Subscriptions | ✅ own nursery only | ❌ | ❌ | ❌ |
| Attachments upload | ✅ | ✅ | ✅ | ❌ |
| Attachments view | ✅ | ✅ | ✅ | ❌ |
| Notifications | ✅ own | ✅ own | ✅ own | ✅ own |
| Audit logs | ❌ (API returns 403) | ❌ | ❌ | ❌ |
| Admin dashboard | ❌ | ❌ | ❌ | ❌ |

---

## 13. Screen-Level List (Corrected)

### Shared Screens

| Screen | Required | API |
|---|---:|---|
| Splash | Yes | token refresh, `GET /users/me`, `GET /me/workspaces` |
| Login | Yes | `POST /auth/send-otp` |
| OTP Verify | Yes | `POST /auth/verify-otp` |
| Create Profile | Yes | `PUT /users/me` |
| Workspace Select | Yes | `GET /me/workspaces` |
| Admin Wall | Yes | Static screen — no business APIs |
| Notifications | Yes | `GET /notifications`, read/delete APIs |
| Profile | Yes | `GET /users/me`, `PUT /users/me`, logout |
| Addresses | Yes | `GET/POST/PUT/DELETE /users/{id}/addresses` |
| Invite Accept | Yes | `GET /invites/{uuid}`, `POST /invites/{uuid}/accept` |
| Plant Catalogue List | Yes (Owner, Manager, Customer) | `GET /plants` |
| Plant Detail | Yes (Owner, Manager, Customer) | `GET /plants/{id}`, care guide, sizes |

### Owner-Specific Screens

| Screen | Required | API |
|---|---:|---|
| Owner Home | Yes | `/me/owner-dashboard`, orders, dispatches, notifications |
| Order List | Yes | `GET /orders` (nursery scope) |
| Order Detail | Yes | `GET /orders/{id}`, items, payments |
| Order Create | Yes | `POST /orders` |
| Order Loading Workflow | Yes | `start-loading`, `complete-loading`, items CRUD |
| Quotation List | Yes | `GET /quotations` |
| Quotation Detail | Yes | `GET /quotations/{id}`, approve, convert, assign |
| Quotation Create | Yes | `POST /quotations` (internal + customer types) |
| Dispatch List | Yes | `GET /dispatches` |
| Dispatch Detail + Trip QR | Yes | `GET/POST/PUT /dispatches`, trip UUID/QR |
| Dispatch Create | Yes | `POST /dispatches` |
| Plant Request List | Yes | `GET /plant-requests` |
| Plant Request Detail | Yes | `GET /plant-requests/{id}`, responses |
| Plant Request Create | Yes | `POST /plant-requests` |
| Sourcing Network | Yes | sourcing APIs |
| Inventory List | Yes | `GET /nurseries/{id}/inventory` |
| Inventory Add | Yes | `POST /inventory` (owner only) |
| Members Screen | Yes | managers list, invites, driver connections |
| Nursery Profile Edit | Yes | `GET/PUT /nurseries/{id}` |
| Subscription | Later | `GET /subscriptions/me` — deferred, do not fake |

### Manager Screens

| Screen | Required | API |
|---|---:|---|
| Manager Home | Yes | assigned orders, quotations, dispatches, requests |
| Work Queue | Yes | orders server-scoped to manager |
| Order Detail (assigned) | Yes | assigned order only |
| Order Create | Yes | `POST /orders` |
| Loading Workflow (assigned) | Yes | assigned orders only — start/complete/items/photos |
| Quotation List (assigned) | Yes | quotations server-scoped |
| Quotation Create | Yes | `POST /quotations` |
| Dispatch List | Yes | `GET /dispatches` (nursery scope) |
| Dispatch Create | Yes | `POST /dispatches` |
| Plant Requests | Yes | `GET/POST /plant-requests` |
| Sourcing Network | Yes | same sourcing APIs as owner |
| Inventory View (read-only) | Later | only if API scoping confirmed — no write controls |

### Driver Screens

| Screen | Required | API |
|---|---:|---|
| Driver Home | Yes | `drivers/me`, `dispatches` |
| Trip List | Yes | `GET /dispatches` (driver scope) |
| Trip Preview (by code/QR) | Yes | `GET /dispatches/code/{code}` |
| Trip Accept Screen | Yes | `POST /dispatches/{id}/accept` |
| Trip Detail | Yes | `GET /dispatches/{id}` |
| GPS Tracker (background service) | Yes | `POST /tracking` |
| Delivery Proof Upload | Yes | `POST /attachments` (entity=DISPATCH) |
| Driver Profile (View Only) | Yes | `GET /drivers/me` — no edit button |
| User Profile Edit | Yes | `PUT /users/me` — name, etc. |

### Customer Screens

| Screen | Required | API |
|---|---:|---|
| Customer Home | Yes | buying quotations/orders |
| Quotations Received | Yes | `GET /quotations?buying=true` |
| Quotation Detail (Accept/Reject) | Yes | buyer-accept, buyer-reject |
| Orders (Buying) | Yes | `GET /orders?buying=true` |
| **Place Order (Buy Plants)** | **Yes** | `POST /orders` — confirmed by test-api.sh |
| Delivery Tracking | Yes | `GET /dispatches/{id}/tracking/latest` or `GET /track/{uuid}` |
| Plant Catalogue Browse | Yes (read-only) | `GET /plants`, `GET /plants/{id}` |
| Register Nursery | Yes | `POST /nurseries` |

> **Removed from Customer Screens:** "Delivery Proof" screen that called `GET /api/v1/attachments`. RBAC: customer = ❌ for all attachment operations.

---

## 14. Exclusion List

These must not be included in the preview unless backend/API support is added and RBAC is updated:

| UI Idea | Why Excluded |
|---|---|
| Online/Offline status toggle | No user presence API |
| Driver On Duty toggle | No duty status API |
| Sync Now / offline queue card | No sync API/queue contract |
| WhatsApp/call shortcuts as core flow | Not an API-backed workflow |
| Owner audit logs on mobile | Current API/RBAC returns `403` for owner — hide until API adds owner scope |
| Manager reports | Manager prohibited by business rules |
| Driver plant catalogue / sourcing | Driver = ❌ by RBAC |
| Customer plant request / sourcing | Customer = ❌ by RBAC |
| Customer delivery proof via `/attachments` | Customer = ❌ for all attachment operations |
| Admin portal features | Web admin only |
| Fake revenue KPIs | Must come from payments/subscriptions APIs — do not invent |
| Full customer directory for managers | Privacy violation — manager cannot see customer mobile or address |
| Delete completed orders / quotes | Business rule violation |
| Driver profile edit on mobile | Only Admin can `PUT /drivers/{id}` |

---

## 15. Empty, Loading, Error, And Privacy States

### Empty States

| Role | Context | Message |
|---|---|---|
| Owner | No active orders | "No active orders. Create an order or send a quotation." |
| Owner | No dispatches | "No dispatches. Create a dispatch after loading is complete." |
| Manager | No assigned orders | "No assigned work. Orders assigned to you will appear here." |
| Manager | No assigned quotations | "No assigned quotations yet." |
| Driver | No active trip | "No active trip. Scan a trip code to join." |
| Driver | Trip list empty | "No trip history yet." |
| Customer | No quotations | "No quotations yet. Quotations from nurseries will appear here." |
| Customer | No orders | "No orders yet." |
| Customer | Tracking — no dispatch | "No active delivery. Track your order once it is dispatched." |

### Loading States

Use skeleton rows/cards matching the final layout. Never show hardcoded demo values after login. All counts on Home tab cards must be `—` or a skeleton badge until the API responds.

### Error States

| HTTP Error | UI Behaviour |
|---|---|
| `401` | Clear session, navigate to Login screen |
| `403` | Hide the action on next render. Show brief toast: "Not allowed for this role" |
| `404` | Show "Not found" empty state with Back button |
| `409` | Show conflict reason from API body — especially important for invite role conflicts |
| Network error | Show "Could not connect" with Retry button; keep last cached data visible if available |

### Privacy Masking On Shared Screens

| Viewer | Field to mask / hide |
|---|---|
| Manager viewing order detail | Customer mobile number — show `•••••••••••` or omit |
| Manager viewing order detail | Customer delivery address — hide entirely |
| Driver viewing dispatch detail | Customer name, mobile, address — show destination only |
| Customer viewing order | Nursery manager details, driver private details |
| Owner | Other nurseries' customer lists, order history, quotation history |

---

## 16. Implementation Phases

### Phase 1: RBAC Audit And Fix

1. Audit every screen against Module Visibility Matrix in §12.
2. Remove customer delivery proof screen that calls `/attachments`.
3. Add "Place Order" flow for customers (confirmed by test-api.sh).
4. Fix order item update/delete path to include `{orderId}` segment.
5. Remove "Edit Profile" button from driver profile screen.
6. Fix invite creation: MANAGER_INVITE = owner only; DRIVER_INVITE + CUSTOMER_INVITE = owner or manager.

### Phase 2: Missing Owner Actions

1. Add "Assign Manager" to order detail screen (owner only).
2. Add "Assign Driver" to order detail screen (owner only).
3. Add "Cancel Order" with reason to order detail screen (owner only).
4. Add "Delete Quotation" to quotation detail (owner only, draft status only).
5. Add "Generate Trip QR" to dispatch detail (owner only).
6. Add "Approve Quotation" and "Convert to Order" to quotation detail (owner + manager).

### Phase 3: Missing Manager Actions

1. Add "Create Dispatch" to manager's dispatch section.
2. Add "Upload Loading Photos" to loading workflow screen.
3. Add "Approve Quotation" and "Convert to Order" to assigned quotation detail.

### Phase 4: Status Value Alignment

1. Replace any UI usage of `LOADING` status badge with `LOADING_STARTED` / `LOADING_COMPLETED`.
2. Add `ACCEPTED` state to dispatch status rendering — shown when driver has accepted trip but nursery has not yet marked `DISPATCHED`.
3. Ensure order item edit controls are shown ONLY when order status = `LOADING_STARTED`, hidden otherwise.

### Phase 5: API Integration Polish

1. Wire all Home tab cards to real API counts — remove all hardcoded numbers.
2. Add loading/empty/error states to every list screen.
3. Add skeleton loaders matching final card layouts.
4. Test all 403 paths: confirm prohibited buttons are hidden before user taps.

### Phase 6: Device QA

1. Test owner login — verify no manager/customer UI visible.
2. Test manager login — verify owner-only buttons absent.
3. Test driver login — verify no order/quotation/sourcing UI.
4. Test customer login — verify no sourcing, no attachments, no nursery ops.
5. Test buyer placing order — confirm POST /orders returns 201 and appears in order list.
6. Test large font setting — verify layout remains readable.
7. Test expired token — verify 401 routes to login.
8. Test 403 paths — verify forbidden actions are hidden, not just grayed out.
9. Test network error — verify retry button and cached data remain visible.

---

## 17. QA Checklist

### Role Isolation

| Check | Expected |
|---|---|
| Owner logs in | Sees only own nursery — no other nursery's data |
| Manager logs in | Sees only assigned/allowed work — no owner-level controls |
| Driver logs in | Sees only trips and driver profile — no orders, quotes, sourcing |
| Customer logs in | Sees only own buying data — no nursery internals, no attachments |
| Admin logs in | Admin Wall screen only — no business transaction UI |

### RBAC Negative Checks

| Check | Expected |
|---|---|
| Driver opens sourcing | UI tab hidden, API would return `403` |
| Customer opens plant requests | UI not shown, API would return `403` |
| Customer opens delivery proof via attachments | UI not shown, API would return `403` |
| Manager cancels order | Cancel button absent from manager order detail |
| Manager sees customer mobile on order | Field masked / hidden |
| Manager creates MANAGER_INVITE | Invite type option absent from manager invite flow |
| Owner opens audit logs | UI hidden — API returns `403` for owner |
| Admin creates order on mobile | Admin Wall screen shown — no business UI |
| Driver edits driver profile | Edit profile button absent — profile screen is read-only |

### API Contract Checks

| Check | Expected |
|---|---|
| No API response | Skeleton then retry/error state |
| Empty list | Role-specific empty state with next-action hint |
| `401` | Auto logout to login screen |
| `403` | Hide forbidden action, brief toast |
| `409` invite conflict | Show human-readable conflict message from API body |
| Large font setting | Layout remains readable, no text clipping |
| Customer places order (POST /orders) | Returns 201, order appears in `GET /orders?buying=true` list |

---

## 18. Open Backend/API Gaps For Mobile

| Gap | Impact | Current Plan |
|---|---|---|
| Owner audit API returns `403` by RBAC even though business rules allow owner to view own nursery audit | Cannot build owner audit screen | Hide audit screen for owner until API adds owner scope |
| No online/duty status API | Cannot build status toggles | Exclude entirely |
| No explicit driver "reject trip" endpoint confirmed | Reject flow unclear | Show "Decline" locally without calling an endpoint; trip remains PENDING; document for backend |
| No `GET /nurseries/{id}/customers` endpoint | Customer list in members screen incomplete | Use accepted CUSTOMER_INVITE list as proxy |
| Nursery PENDING/APPROVED/REJECTED status not in `GET /me/workspaces` response | Cannot smart-route from splash to approval status screen | Check nursery detail separately on splash |
| Storage/S3 provider is mocked | Upload UX works only in dev/mock | Show upload only in flows confirmed working; handle S3 errors gracefully |
| Payments provider is mocked | Do not show revenue-heavy UI | Show only order-linked payment status if wired |
| Subscription UX not built in mobile | Owner subscription screen deferred | Hide from first preview or mark as backlog |
| Reopen loading — API endpoint not confirmed | Cannot build reopen loading button | Hide until endpoint confirmed, then add owner-only |

---

## 19. Final Preview Acceptance Criteria

The preview is acceptable only if:

1. Four mobile roles have separate home experiences — owner, manager, driver, customer.
2. Every visible action maps to a current API endpoint confirmed in `test-api.sh`.
3. Every visible data card maps to current DB/API data — no placeholder counts.
4. RBAC-prohibited actions are **hidden**, not just disabled.
5. No role sees extra information outside its business purpose.
6. Driver sees no nursery operations, no orders, no catalogue.
7. Customer sees no internal nursery operations, no sourcing, no attachment endpoints.
8. Manager sees no owner-only controls (assign driver, cancel order, delete quotation, generate QR, manage managers list).
9. Owner sees only own nursery — never another nursery's customer or financial data.
10. Admin is not treated as a mobile business user — Admin Wall only.
11. Customer can place a buying order (`POST /orders`) — confirmed by `test-api.sh`.
12. Driver profile screen is read-only — no edit driver details button.
13. Order item edit controls appear **only** when order status = `LOADING_STARTED`.
14. Dispatch status `ACCEPTED` is handled in trip detail and driver home screen.
15. Delivery proof for customer is via dispatch tracking only — not via `/attachments`.
