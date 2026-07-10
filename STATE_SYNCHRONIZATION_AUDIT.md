# GreenRoot Mobile — State Synchronization Audit

**Date:** 2026-07-10
**Audited by:** Claude Code (automated)
**Scope:** All mutation paths in `/lib/features/` that touch the server (POST, PUT, PATCH, DELETE) and whether the UI refreshes automatically after success.

---

## Summary

| Category | Count |
|---|---|
| Total mutations audited | 47 |
| ✅ OK (auto-refreshes correctly) | 27 |
| ⚠️ PARTIAL (detail view updates, list stale OR minor missing scope) | 8 |
| ❌ MISSING (list/parent view stays stale after mutation) | 12 |

**Key Pattern:** StateNotifier-based list providers (`orderListProvider`, `quotationListProvider`, `vehicleListProvider`, `requestListProvider`, `dispatchListProvider`) require `.load()` on the notifier to refresh. They cannot be invalidated with `ref.invalidate()`. Most detail screens that mutate state only invalidate the FutureProvider for the detail view and forget the parent list.

**Navigation Pattern:** Several list screens push to a detail route using bare `context.push('/route')` (no `await` / no `.then()` check), so even if the detail screen pops with `true`, the list screen never sees it.

---

## Mutation Inventory

### Orders

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 1 | `confirmOrder` (PUT) | `order_detail_screen.dart` via `_doAction()` | `orderDetailProvider(id)` only | ⚠️ PARTIAL — `orderListProvider` and `buyingOrderListProvider` not refreshed |
| 2 | `startLoading` (PUT) | `order_detail_screen.dart` via `_doAction()` | `orderDetailProvider(id)` only | ⚠️ PARTIAL — same |
| 3 | `completeLoading` (PUT) | `order_detail_screen.dart` via `_doAction()` | `orderDetailProvider(id)` only | ⚠️ PARTIAL — same |
| 4 | `cancelOrder` (PUT) | `order_detail_screen.dart` via `_doAction()` | `orderDetailProvider(id)` only | ⚠️ PARTIAL — same |
| 5 | `markCompleted` (PUT) | `order_detail_screen.dart` via `_doAction()` | `orderDetailProvider(id)` only | ⚠️ PARTIAL — same |
| 6 | `createDispatch` (POST) | `order_detail_screen.dart: _createDispatch` | `orderDetailProvider(id)` + `_orderDispatchesProvider(id)` | ⚠️ PARTIAL — `dispatchListProvider` not reloaded; driver not notified |
| 7 | `assignManager` on order (PUT) | `order_detail_screen.dart: _assignManager` | `orderDetailProvider(id)` only | ⚠️ PARTIAL — `orderListProvider` not reloaded |
| 8 | `createOrder` (POST) | `order_list_screen.dart` via FAB → `context.push<bool>('/orders/create')` | `orderListProvider.load()` if `created == true` | ✅ OK |

### Quotations

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 9 | Buyer `acceptQuotation` (POST) | `quotation_detail_screen.dart: _buyerAccept` | `context.pop(true)` → `buyer_tab.dart` reloads `_buyerQuotationProvider` | ✅ OK |
| 10 | Buyer `rejectQuotation` (POST) | `quotation_detail_screen.dart: _buyerReject` | `context.pop(true)` → `buyer_tab.dart` reloads `_buyerQuotationProvider` | ✅ OK |
| 11 | Seller `approveQuotation` (POST) | `quotation_detail_screen.dart: _approve` | `quotationDetailProvider(id)` only | ❌ MISSING — `quotationListProvider` not reloaded (no `context.pop(true)`) |
| 12 | Seller `recallQuotation` (POST) | `quotation_detail_screen.dart: _recall` | `quotationDetailProvider(id)` only | ❌ MISSING — `quotationListProvider` not reloaded |
| 13 | Seller `assignManager` on quotation (PUT) | `quotation_detail_screen.dart: _assignManager` | `quotationDetailProvider(id)` only | ❌ MISSING — `quotationListProvider` not reloaded |
| 14 | `convertToOrder` (POST) | `quotation_detail_screen.dart: _convertToOrder` | `quotationDetailProvider(id)` only | ❌ MISSING — `quotationListProvider` not reloaded, `orderListProvider` not notified |
| 15 | `deleteQuotation` (DELETE) | `quotation_detail_screen.dart: _confirmDelete` | `context.pop(true)` → caller checks return and calls `quotationListProvider.load()` | ✅ OK |
| 16 | `createQuotation` (POST) | `quotation_list_screen.dart` + `manager_work_tab.dart` via `context.push<bool>('/quotations/create')` | `quotationListProvider.load()` if `created == true` | ✅ OK |
| 17 | `updateQuotation` (PUT) | `quotation_detail_screen.dart` (edit nav) | `quotationDetailProvider(id)` via `ref.invalidate` on `edited == true` | ✅ OK — detail refreshed; list also reloads because edit pops with `true` |

### Dispatches (Nursery-side)

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 18 | `updateStatus` DISPATCHED/CANCELLED (PUT) | `dispatch_detail_screen.dart: _updateStatus` | `dispatchDetailProvider(id)` only | ⚠️ PARTIAL — `dispatchListProvider` not reloaded; order status not signaled |
| 19 | `createDispatch` (POST) | (called from `order_detail_screen._createDispatch`) | `orderDetailProvider(id)` + `_orderDispatchesProvider(id)` | ⚠️ PARTIAL — `dispatchListProvider` not updated (see #6 above) |

### Dispatches (Driver-side)

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 20 | `acceptDispatch` (POST) | `trip_detail_screen.dart: _acceptTrip` | `dispatchDetailProvider(id)` + `activeDriverTripProvider` | ✅ OK |
| 21 | `acceptDispatch` (POST) | `driver_trip_map_screen.dart: _acceptTrip` | `dispatchDetailProvider(id)` only | ⚠️ PARTIAL — `activeDriverTripProvider` not invalidated here; `_driverDashboardProvider` not invalidated |
| 22 | `updateStatus` IN_TRANSIT (PUT) | `trip_detail_screen.dart: _startTrip` | `dispatchDetailProvider(id)` + `activeDriverTripProvider` | ✅ OK |
| 23 | `updateStatus` IN_TRANSIT (PUT) | `driver_trip_map_screen.dart: _startJourney` | `dispatchDetailProvider(id)` only | ⚠️ PARTIAL — `activeDriverTripProvider` + `_driverDashboardProvider` not invalidated |
| 24 | `updateStatus` DELIVERED (PUT) | `trip_detail_screen.dart: _completeDelivery` | `dispatchDetailProvider(id)` + `activeDriverTripProvider` | ✅ OK |
| 25 | `updateStatus` DELIVERED (PUT) | `driver_trip_map_screen.dart: _completeDelivery` | `dispatchDetailProvider(id)` + `activeDriverTripProvider` | ✅ OK |
| 26 | `addTripEvent` (POST) | `trip_event_screen.dart: _submit` | `dispatchDetailProvider(id)` | ✅ OK — events are embedded in dispatch detail |
| 27 | `postGpsLocation` (POST) | `driver_trip_map_screen.dart` (periodic timer) | No provider — fire and forget | ✅ OK — tracking is write-only telemetry |

### Local Market

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 28 | `createAd` (POST) | `local_market_providers.dart: _PostAdNotifier.create` | `myAdsProvider` only | ❌ MISSING — `latestAdsProvider` and `browseAdsProvider` not invalidated; new ad invisible to browsing |
| 29 | `updateAd` (PUT) | `local_market_providers.dart: _PostAdNotifier.update` | `myAdsProvider` only | ❌ MISSING — `browseAdsProvider`, `savedAdsProvider`, `latestAdsProvider` not invalidated |
| 30 | `performAdAction` publish/pause/resume/archive/renew (PUT) | `local_market_providers.dart: _PostAdNotifier` | `myAdsProvider` + `latestAdsProvider` | ✅ OK |
| 31 | `toggleSaveAd` (POST/DELETE) | `local_market_providers.dart: _ToggleSaveNotifier.toggle` | `adSavedProvider(adId)` local state only | ❌ MISSING — `savedAdsProvider` list not invalidated; saved-ads screen stays stale |
| 32 | `sendEnquiry` (POST) | `local_market_providers.dart` | `receivedEnquiriesProvider` + `sentEnquiriesProvider` | ⚠️ PARTIAL — ad-level enquiry count not updated |
| 33 | `replyToEnquiry` (POST) | `local_market_providers.dart` | `enquiryDetailProvider` + `receivedEnquiriesProvider` + `sentEnquiriesProvider` | ✅ OK |

### Inventory

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 34 | `upsert` / add inventory (POST) | `inventory_add_screen.dart: _save` | `Navigator.pop(true)` — but `inventory_list_screen` uses bare `context.push('/inventory/add')` (no `.then()` / no `await`) | ❌ MISSING — list never reloaded on return |
| 35 | `update` inventory (PUT) | Not yet implemented (screen has TODO comment) | N/A | N/A — feature not built yet |

### Vehicles

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 36 | `createVehicle` (POST) | `vehicle_form_screen.dart: _save` | `context.pop()` — `vehicle_list_screen` uses `context.push('/vehicles/create').then((_) { notifier.load() })` | ✅ OK — list always reloads unconditionally on any pop |
| 37 | `updateVehicle` (PUT) | `vehicle_form_screen.dart: _save` | `context.pop()` — `vehicle_list_screen` uses `.then((_) { notifier.load() })` on edit nav too | ✅ OK — same |
| 38 | `deleteVehicle` (DELETE) | `vehicles.dart: VehicleListNotifier.deleteVehicle` | Updates state directly via filter | ✅ OK |

### Plant Requests

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 39 | `createRequest` (POST) | `request_create_screen.dart: _save` | `Navigator.pop(true)` — but `request_list_screen` uses bare `context.push('/requests/create')` (no return check) | ❌ MISSING — list never reloaded on return |
| 40 | `respondToRequest` (PUT) | `request_detail_screen.dart` | N/A — screen appears read-only; no mutation UI found | N/A |

### Members & Invites

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 41 | `createInvite` (POST) — nursery context | `owner_members_screen.dart: MembersNotifier.createInvite` | `await load()` called inside the notifier after success | ✅ OK — list auto-refreshes |
| 42 | `sendInvite` (POST) — connections context | `connections_screen.dart: _invite` | No invalidation; shows QR sheet | ❌ MISSING — `ownerDashboardProvider` connection counts not refreshed |
| 43 | `acceptInvite` (POST) | `invite_accept_screen.dart: InviteNotifier.accept` | Sets `accepted = true` in notifier → `context.pop()` or `context.go('/')` | ⚠️ PARTIAL — session/workspace not explicitly refreshed after role change; relies on next cold load |

### Top Items (Featured Plants)

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 44 | `add` featured plant (POST) | `top_items_screen.dart: _TopItemsNotifier.add` | `state = AsyncValue.data([...current, added])` direct state update | ✅ OK |
| 45 | `remove` featured plant (DELETE) | `top_items_screen.dart: _TopItemsNotifier.remove` | `state = AsyncValue.data(current.where(...).toList())` direct state update | ✅ OK |

### Subscriptions

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 46 | `renewSubscription` / mock payment (POST) | `subscription_payment_screen.dart: _pay` | Nothing — mock success shows modal but does NOT invalidate `subscriptionProvider` | ❌ MISSING — subscription screen will remain stale even when real payment is wired |

### Profile & Notifications

| # | Mutation | File | Invalidates | Status |
|---|---|---|---|---|
| 47 | `updateProfile` (PUT) | `edit_profile_screen.dart: _save` | `ref.read(sessionProvider.notifier).updateUser(updated)` | ✅ OK |
| 48 | `uploadAvatar` (POST) | `edit_profile_screen.dart: _pickAndUploadImage` | `ref.read(sessionProvider.notifier).updateUser(updated)` | ✅ OK |
| 49 | `markRead` (PUT) | `notifications.dart: NotificationListNotifier.markRead` | Direct state update | ✅ OK |
| 50 | `markAllRead` (PUT) | `notifications.dart: NotificationListNotifier.markAllRead` | Direct state update | ✅ OK |
| 51 | `deleteNotification` (DELETE) | `notifications.dart: NotificationListNotifier.deleteNotification` | Direct state update | ✅ OK |

---

## Issues by Category

### Category A — Detail action doesn't signal list (CRITICAL)

The most common gap: a mutation in a detail screen refreshes only the detail provider, but the calling list screen never reloads because (a) the screen never awaits the push result, or (b) the detail screen never calls `context.pop(true)` to signal a change occurred.

**Affected mutations:**
- All 5 order status mutations in `order_detail_screen._doAction()` — only `orderDetailProvider` invalidated; `order_list_screen` navigates to detail with bare `context.push('/orders/${order.id}')` (no return check), so the list is never told to reload.
- `_approve` and `_recall` in `quotation_detail_screen` — only `quotationDetailProvider` invalidated; `quotation_list_screen` checks `if (edited == true) load()` but the detail screen never pops with `true` for these actions.
- `_assignManager` in `quotation_detail_screen` — same pattern.
- `_convertToOrder` in `quotation_detail_screen` — detail refreshed; `quotationListProvider` and `orderListProvider` both stale.
- `createDispatch` in `order_detail_screen` — `dispatchListProvider` not reloaded.
- `updateStatus` in `dispatch_detail_screen` (nursery-side DISPATCHED/CANCELLED) — `dispatchListProvider` not reloaded.

### Category B — Create screen pops but list ignores return (HIGH)

The create screen calls `Navigator.pop(true)` after success, but the list screen pushed to the create route without `.then()` or `await` result handling, so the pop value is discarded.

**Affected mutations:**
- `inventory_add_screen._save` — `inventory_list_screen` uses `context.push('/inventory/add')` with no return handling.
- `request_create_screen._save` — `request_list_screen` uses `context.push('/requests/create')` with no return handling.

### Category C — Wrong or incomplete provider invalidation (MEDIUM)

The mutation invalidates something, but misses related providers that display the same data in different screens.

**Affected mutations:**
- `local_market: createAd` — invalidates `myAdsProvider` but not `latestAdsProvider` or `browseAdsProvider`.
- `local_market: updateAd` — invalidates `myAdsProvider` but not `browseAdsProvider` or `savedAdsProvider`.
- `local_market: toggleSaveAd` — updates `adSavedProvider(adId)` (the heart icon) but never reloads `savedAdsProvider` (the saved ads list screen).
- `driver_trip_map_screen: _acceptTrip` — does not invalidate `activeDriverTripProvider` or `_driverDashboardProvider`; `trip_detail_screen._acceptTrip` does both correctly.
- `driver_trip_map_screen: _startJourney` — does not invalidate `activeDriverTripProvider` or `_driverDashboardProvider`.

### Category D — Mutation success leaves dashboards stale (LOW-MEDIUM)

**Affected mutations:**
- `connections_screen: sendInvite` — after invite is sent, the connection counts on `ownerDashboardProvider` are not refreshed.
- `subscription_payment_screen: _pay` — even the mock success does not invalidate `subscriptionProvider`; the subscription screen in profile will remain stale.
- `invite_accept_screen: accept` — after accepting an invite, the user's session/workspace is not explicitly refreshed; the role change takes effect only after the next cold app start or explicit navigation.

---

## Recommended Fixes

### Fix 1 — Order detail: pop with signal or invalidate list after action

**File:** `lib/features/orders/order_detail_screen.dart`

The `_doAction()` method should also reload `orderListProvider` and `buyingOrderListProvider` after success:

```dart
// In _doAction(), after ref.invalidate(orderDetailProvider(widget.orderId)):
try {
  ref.read(orderListProvider.notifier).load();
} catch (_) {}
try {
  ref.read(buyingOrderListProvider.notifier).load();
} catch (_) {}
```

Or alternatively: pop with `true` and have list screens check the return value (matches the pattern used for create).

### Fix 2 — Quotation detail: pop with signal for approve/recall/assignManager/convert

**File:** `lib/features/quotations/quotation_detail_screen.dart`

After `_approve`, `_recall`, `_assignManager`, and `_convertToOrder` succeed, add `if (mounted) context.pop(true)` to let the list screens reload. The seller `quotation_list_screen` already has:

```dart
final edited = await context.push<bool>('/quotations/${q.id}');
if (edited == true) ref.read(quotationListProvider.notifier).load();
```

So the fix is only needed in the detail screen.

For `_convertToOrder`, additionally reload `orderListProvider`:

```dart
ref.read(orderListProvider.notifier).load();
```

### Fix 3 — Inventory list: check return value from add screen

**File:** `lib/features/inventory/inventory_list_screen.dart`

Change:
```dart
onPressed: () => context.push('/inventory/add'),
```
To:
```dart
onPressed: () async {
  final added = await context.push<bool>('/inventory/add');
  if (added == true && mounted) {
    ref.read(inventoryListProvider.notifier).load();
  }
},
```

### Fix 4 — Plant request list: check return value from create screen

**File:** `lib/features/plant_requests/request_list_screen.dart`

Same pattern as Fix 3:
```dart
onPressed: () async {
  final created = await context.push<bool>('/requests/create');
  if (created == true && mounted) {
    ref.read(requestListProvider.notifier).load();
  }
},
```

### Fix 5 — Local market: invalidate browse/latest/saved after createAd and updateAd

**File:** `lib/features/market/local_market_providers.dart`

In `_PostAdNotifier.create()`, after invalidating `myAdsProvider`, also invalidate:
```dart
_ref.invalidate(latestAdsProvider);
_ref.invalidate(browseAdsProvider);
```

In `_PostAdNotifier.update()`, also invalidate:
```dart
_ref.invalidate(browseAdsProvider);
_ref.invalidate(savedAdsProvider);
_ref.invalidate(latestAdsProvider);
```

### Fix 6 — toggleSaveAd: invalidate savedAdsProvider

**File:** `lib/features/market/local_market_providers.dart`

In `_ToggleSaveNotifier.toggle()`, after updating local state:
```dart
_ref.invalidate(savedAdsProvider);
```

### Fix 7 — Driver trip map: invalidate activeDriverTripProvider after accept and startJourney

**File:** `lib/features/drivers/driver_trip_map_screen.dart`

In `_acceptTrip()` and `_startJourney()`, add after `ref.invalidate(dispatchDetailProvider(...))`:
```dart
ref.invalidate(activeDriverTripProvider);
// and optionally:
ref.invalidate(_driverDashboardProvider);
```

### Fix 8 — Subscription payment: invalidate subscriptionProvider after payment

**File:** `lib/features/subscriptions/subscription_payment_screen.dart`

After the success state is shown (and when real payment is wired):
```dart
ref.invalidate(subscriptionProvider);
```

### Fix 9 — Connections: refresh dashboard after invite sent

**File:** `lib/features/connections/connections_screen.dart`

After `sendInvite` succeeds:
```dart
ref.invalidate(ownerDashboardProvider);
```

### Fix 10 — Order list screen: await detail navigation result

**File:** `lib/features/orders/order_list_screen.dart` (and `buyer_tab.dart`, `manager_work_tab.dart`)

For the order detail tap, consider awaiting and reloading:
```dart
onTap: () async {
  await context.push('/orders/${order.id}');
  if (mounted) ref.read(orderListProvider.notifier).load();
},
```

---

## Files That Need Changes

| File | Mutations Affected | Fixes |
|---|---|---|
| `lib/features/orders/order_detail_screen.dart` | #1–7 | Fix 1 |
| `lib/features/orders/order_list_screen.dart` | #1–5 (list not notified) | Fix 10 |
| `lib/features/buyer/buyer_tab.dart` | #1–5 (buyer order list not notified) | Fix 10 (buyer variant) |
| `lib/features/manager/manager_work_tab.dart` | #1–5 (mgr order list not notified) | Fix 10 (manager variant) |
| `lib/features/quotations/quotation_detail_screen.dart` | #11–14 | Fix 2 |
| `lib/features/inventory/inventory_list_screen.dart` | #34 | Fix 3 |
| `lib/features/plant_requests/request_list_screen.dart` | #39 | Fix 4 |
| `lib/features/market/local_market_providers.dart` | #28, 29, 31 | Fixes 5, 6 |
| `lib/features/drivers/driver_trip_map_screen.dart` | #21, 23 | Fix 7 |
| `lib/features/subscriptions/subscription_payment_screen.dart` | #46 | Fix 8 |
| `lib/features/connections/connections_screen.dart` | #42 | Fix 9 |

---

## Verification Checklist

After fixes are applied, test each scenario manually:

### Orders
- [ ] Seller confirms an order → seller order list shows CONFIRMED status immediately on back
- [ ] Manager starts loading → order list updates status immediately on back
- [ ] Manager completes loading → order list updates status immediately on back
- [ ] Order is cancelled → order list shows CANCELLED on back
- [ ] Buyer view: accepts an order (from detail) → buyer order list shows updated status
- [ ] Seller creates a dispatch → dispatch list screen shows new entry

### Quotations
- [ ] Seller approves a quotation → quotation list shows APPROVED on back (without needing manual pull-to-refresh)
- [ ] Seller recalls a quotation → quotation list updates on back
- [ ] Seller converts quotation to order → quotation shows CONVERTED; order list shows new order
- [ ] Buyer accepts quotation → buyer quotation list updates (currently works ✅ — verify regression)
- [ ] Buyer rejects quotation → buyer quotation list updates (currently works ✅ — verify regression)
- [ ] Delete quotation → removed from list (currently works ✅ — verify regression)

### Inventory
- [ ] Add inventory item → inventory list shows new item immediately on back (no pull-to-refresh needed)

### Plant Requests
- [ ] Create plant request → request list shows new entry immediately on back

### Local Market
- [ ] Post a new ad → ad appears in Browse and Latest tabs (not just My Ads)
- [ ] Update an ad → changes visible in Browse and Saved Ads
- [ ] Save/unsave an ad → Saved Ads list reflects change without needing manual refresh

### Dispatches
- [ ] Driver accepts trip in map screen → driver dashboard (home) shows trip card without needing manual refresh
- [ ] Driver starts journey in map screen → driver dashboard updates

### Subscriptions
- [ ] Complete (mock) payment → subscription screen shows new/active subscription status

### Connections
- [ ] Send invite → owner dashboard connection count updates

---

## Notes on Architecture

**StateNotifier vs FutureProvider invalidation:**
`orderListProvider`, `quotationListProvider`, `buyingOrderListProvider`, `buyingQuotationListProvider`, `dispatchListProvider`, `vehicleListProvider`, `requestListProvider`, `inventoryListProvider` are all `StateNotifierProvider`. Calling `ref.invalidate()` on them does NOT trigger a refetch — it only resets the notifier state. The correct way to refresh is `ref.read(provider.notifier).load()`.

**Cross-screen pop contract:**
The codebase uses two patterns for create/edit → list sync:
1. **Unconditional `.then(() => load())`** — list always reloads when returning from any push (used in `VehicleListScreen`). Simple, slightly wasteful.
2. **`await push<bool>()` + `if (result == true) load()`** — only reloads if mutation actually happened (used in order create, quotation create). More precise but requires the detail/create screen to consistently return `true` on success.

Both patterns work correctly when applied. The gaps occur when:
- A detail screen was added after the list screen, and the list screen's `onTap` was never updated to await the result.
- A new mutation was added to an existing detail screen without adding the corresponding `context.pop(true)`.
