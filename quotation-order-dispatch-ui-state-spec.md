# GreenRoot Quotation → Order → Dispatch UI and Technical State Specification

## Purpose

This document defines what each user should see during the complete GreenRoot lifecycle:

```text
Quotation
→ Order
→ Loading
→ Dispatch
→ Driver Acceptance
→ Journey
→ Delivery
→ Completion
```

It also defines expected behavior for:

* Flutter / Dart mobile UI
* Go API
* PostgreSQL
* PostGIS
* Redis
* Redis GEO
* OpenStreetMap
* Driver live-location tracking
* RBAC
* Notifications
* Background location updates

This document should be treated as the reference when reviewing or improving existing mobile pages.

Before making changes:

1. Inspect the existing DB statuses, API transitions, Flutter screens, providers, repositories and navigation.
2. Reuse existing pages and components wherever possible.
3. Do not create duplicate pages, APIs, statuses or state machines.
4. Fix inconsistencies between API, DB and mobile.
5. Preserve existing RBAC, masking, subscription and audit rules.
6. Avoid overengineering V1.

---

# 1. User Types

The three user-facing types covered in this workflow are:

| User type        | Meaning                              |
| ---------------- | ------------------------------------ |
| Owner / Manager  | Nursery operations user              |
| Customer / Buyer | User receiving quotation and order   |
| Driver           | Independent driver handling delivery |

Admin visibility is separate and should show the full lifecycle through the admin dashboard.

---

# 2. Canonical Lifecycle

## Quotation

```text
CUSTOMER_DRAFT
→ CUSTOMER_SENT
→ CUSTOMER_ACCEPTED
→ CONVERTED
```

Alternative outcomes:

```text
CUSTOMER_SENT
→ CUSTOMER_REJECTED

CUSTOMER_SENT
→ CUSTOMER_DRAFT through Recall

CUSTOMER_SENT + valid_until passed
→ Effective EXPIRED
```

## Order

```text
PENDING
→ CONFIRMED
→ LOADING
→ LOADED or PARTIALLY_FULFILLED
→ COMPLETED
```

## Dispatch

```text
PENDING
→ ACCEPTED
→ DISPATCHED
→ IN_TRANSIT
→ DELIVERED
```

Cancellation for V1:

```text
Dispatch PENDING or ACCEPTED
→ CANCELLED
```

Normal cancellation should be blocked after `DISPATCHED`.

---

# 3. Complete UI and Technical State Matrix

|  # | Business state                           | Owner / Manager UI                                                                                                      | Customer UI                                                                   | Driver UI                                                                                                    | Flutter / Dart behavior                                                                                                                                            | Maps behavior                                                                                                                                | Redis / Redis GEO                                                                                                                                                    | PostGIS / PostgreSQL                                                                                         | API expectations                                                                                           |
| -: | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
|  1 | Quotation `CUSTOMER_DRAFT`               | Show Draft badge. Editable customer, items, quantities, price, notes and validity. Primary button: **Send to Customer** | Nothing                                                                       | Nothing                                                                                                      | Load quotation through quotation repository. Enable form controls based on edit permission and assignment. Use form validation before send                         | No map                                                                                                                                       | No Redis GEO usage                                                                                                                                                   | Store quotation and items. Store `customer_user_id`, `valid_until`, assignee and audit data                  | Allow update and send only for permitted owner/manager. Validate ownership and assignment                  |
|  2 | Quotation `CUSTOMER_SENT`                | Show Sent badge. Read-only unless recalled. Actions: **Recall**, View PDF, Share                                        | Show new quotation with items, total, validity and Accept/Reject buttons      | Nothing                                                                                                      | Customer app fetches own sent quotations. Hide editing controls. Show countdown or validity date                                                                   | No map                                                                                                                                       | Optional notification cache only                                                                                                                                     | DB remains `CUSTOMER_SENT`                                                                                   | Accept/Reject only when not expired. Recall only before customer response                                  |
|  3 | Quotation recalled to `CUSTOMER_DRAFT`   | Show editable Draft again. Primary button: **Send to Customer**                                                         | Remove from actionable list. Optionally show “Recalled by Nursery” in history | Nothing                                                                                                      | Invalidate quotation list providers for owner and customer after recall                                                                                            | No map                                                                                                                                       | Remove or invalidate any cached actionable quotation entry                                                                                                           | Update status back to `CUSTOMER_DRAFT`. Preserve audit history                                               | Block customer Accept/Reject after recall                                                                  |
|  4 | Quotation `CUSTOMER_ACCEPTED`            | Show Accepted badge. Primary button: **Convert to Order**                                                               | Show Accepted. Message: “The nursery will prepare your order.”                | Nothing                                                                                                      | Refresh quotation detail and available actions after acceptance                                                                                                    | No map                                                                                                                                       | Optional cache invalidation                                                                                                                                          | Store accepted timestamp and accepted-by user                                                                | Conversion allowed only once and only from accepted status                                                 |
|  5 | Quotation `CUSTOMER_REJECTED`            | Show rejection reason. Actions: View, Duplicate, Create Revised Quotation                                               | Show Rejected with submitted reason                                           | Nothing                                                                                                      | Read-only detail page. Hide conversion actions                                                                                                                     | No map                                                                                                                                       | No GEO usage                                                                                                                                                         | Store dedicated `rejection_reason` and timestamp                                                             | Block conversion and further response                                                                      |
|  6 | Effective quotation `EXPIRED`            | Show Expired badge. Actions: Duplicate or Create Revised Quotation                                                      | Show Expired. Hide Accept/Reject                                              | Nothing                                                                                                      | Derive effective status using `valid_until`. Do not depend only on stored status                                                                                   | No map                                                                                                                                       | Cached quotation should respect expiry or use a short TTL                                                                                                            | Stored DB status may remain `CUSTOMER_SENT`; derive effective expiry                                         | API must block Accept, Reject and Convert after expiry                                                     |
|  7 | Quotation `CONVERTED`                    | Show linked order summary. Primary action: **View Order**                                                               | Show “Order Created”. Primary action: **View Order**                          | Nothing                                                                                                      | Navigate using linked `order_id`. Disable all quotation mutation controls                                                                                          | No map                                                                                                                                       | Invalidate quotation and order caches                                                                                                                                | Store conversion link and lock quotation                                                                     | Conversion must be idempotent and block duplicate orders                                                   |
|  8 | Order `PENDING`                          | Show New Order / Waiting for Confirmation. Primary button: **Confirm Order**. Secondary: Cancel                         | Show Order Submitted. Message: “Waiting for nursery confirmation.”            | Nothing                                                                                                      | Load order using order repository. Render actions based on role and state                                                                                          | No route map yet                                                                                                                             | Optional order summary cache                                                                                                                                         | Store order items, customer, seller nursery and source quotation                                             | Only permitted roles may confirm. Buyer cancellation only when allowed                                     |
|  9 | Order `CONFIRMED`                        | Show Order Confirmed. Primary button: **Start Loading**. Optionally assign loading responsibility                       | Show Confirmed. Message: “The nursery is preparing your plants.”              | Nothing                                                                                                      | Owner/manager sees loading action. Customer sees read-only progress                                                                                                | No live map                                                                                                                                  | Cache may be invalidated after confirmation                                                                                                                          | Store confirmation timestamp and actor                                                                       | Only valid `PENDING → CONFIRMED` transition                                                                |
| 10 | Order `LOADING`                          | Show Loading in Progress. Edit loaded quantities and add loading photos. Primary button: **Complete Loading**           | Show Loading in Progress and optional quantity progress                       | Nothing unless an early dispatch assignment exists                                                           | Use item-level loading forms. Prevent quantities above ordered quantity. Support retry and optimistic UI carefully                                                 | Optional static loading-location preview                                                                                                     | Redis may hold temporary loading progress or active workflow locks. Do not use Redis as source of truth                                                              | Persist loaded quantities and loading events in PostgreSQL                                                   | Validate quantities and permissions. Block completion when required data is missing                        |
| 11 | Order `LOADED`, no dispatch              | Show Loading Completed. Primary button: **Create Dispatch**                                                             | Show Loading Completed. Message: “Dispatch is being arranged.”                | Nothing                                                                                                      | Owner page checks whether active dispatch exists before showing Create Dispatch                                                                                    | Optional static map showing loading and delivery locations                                                                                   | No active driver GEO entry yet                                                                                                                                       | Order status `LOADED`; no active dispatch row                                                                | API must block duplicate active dispatches                                                                 |
| 12 | Order `PARTIALLY_FULFILLED`, no dispatch | Show Partial Loading Completed with ordered vs loaded quantities. Primary button: **Create Dispatch**                   | Show reduced quantity notice and dispatch-arrangement message                 | Nothing                                                                                                      | Render quantity comparison clearly. Require acknowledgement where needed                                                                                           | Optional loading/delivery preview                                                                                                            | No active driver GEO entry                                                                                                                                           | Preserve original and loaded quantities                                                                      | Dispatch creation allowed if business rules permit partial delivery                                        |
| 13 | Dispatch `PENDING`                       | Show Dispatch Created. Display QR, Trip ID, vehicle/loading/delivery details. Actions: Share QR, Cancel Dispatch        | Show “Driver assignment pending.” Do not expose QR or internal Trip ID        | Show Join Trip screen with QR scanner and Trip ID input                                                      | Flutter QR scanner validates scanned payload before accepting. Deep link or manual ID supported                                                                    | Show static loading and delivery markers only after driver previews trip                                                                     | Redis may store short-lived join token validation, attempt limits or active dispatch lookup cache                                                                    | Dispatch row stores loading and delivery coordinates, trip UUID and status                                   | API verifies trip UUID, dispatch status, driver eligibility and one-active-trip rule                       |
| 14 | Driver scans QR, before acceptance       | Show Waiting for Driver Acceptance                                                                                      | Continue showing Driver Assignment Pending                                    | Show trip preview: nursery, pickup, delivery, vehicle and estimated distance. Buttons: **Accept Trip**, Back | Do not join automatically on scan. Show confirmation page first                                                                                                    | Show route preview with loading and delivery pins. External Google Maps/OpenStreetMap redirect may be offered                                | No live GEO tracking yet. Short TTL cache may hold validated trip preview                                                                                            | Use PostGIS to calculate loading-to-delivery distance where useful                                           | Accept endpoint must be transactional and enforce one active trip                                          |
| 15 | Dispatch `ACCEPTED`                      | Show Driver Accepted with driver and vehicle. Primary button: **Mark as Dispatched**. Secondary: View Dispatch          | Show Driver Assigned — Awaiting Dispatch                                      | Show Trip Accepted. Message: “Waiting for nursery dispatch confirmation.” No Start Journey button            | Refresh owner, customer and driver providers after acceptance. Driver home should show active trip instead of Join Trip                                            | Show pickup/loading and delivery locations. Driver current location may be shown only locally, not yet shared as active journey              | Optionally register driver-active-trip mapping. Do not start high-frequency GEO writes yet                                                                           | Store assigned driver, acceptance timestamp and vehicle                                                      | Block direct `ACCEPTED → IN_TRANSIT` if canonical flow requires `DISPATCHED` first                         |
| 16 | Dispatch `DISPATCHED`                    | Show Vehicle Dispatched and dispatch time. Monitor until driver starts journey                                          | Show Order Dispatched. Message: “Your order has left the nursery.”            | Show Ready to Start Journey. Primary button: **Start Journey**                                               | Driver page enables location permission check and journey-start action                                                                                             | Display current driver position, loading point and delivery point. Route guidance may redirect to external maps                              | Create active-trip Redis keys. Prepare GEO tracking session with TTL                                                                                                 | Store dispatched timestamp. PostGIS retains permanent coordinates                                            | Start Journey endpoint allows only assigned driver or authorised owner/manager                             |
| 17 | Dispatch `IN_TRANSIT`                    | Show In Transit with live driver location and last-updated time. Actions: Call Driver, View Tracking                    | Show On the Way. Show live location when enabled                              | Show In Transit map, destination, distance and journey actions                                               | Start background location updates. Handle app background, reconnect, permission denial and battery constraints. Update map only when location meaningfully changes | Show three markers: driver live location, loading location and delivery location. Use OpenStreetMap tiles. Do not embed paid Google Maps SDK | Use Redis GEO for latest driver coordinates and nearby/distance queries. Store keys with expiry. Publish live updates through polling, WebSocket or SSE if available | PostGIS stores permanent pickup/delivery geometry and optional sampled tracking history. Use spatial indexes | Location endpoint validates assigned driver, active dispatch and reasonable coordinates. Apply rate limits |
| 18 | Driver reaches near delivery location    | Show Driver Near Delivery Location or Reached Destination                                                               | Show Driver Arriving / Driver Has Arrived                                     | Show Reached Destination button or auto-suggest based on proximity                                           | Flutter may detect geofence proximity locally, but server must verify independently                                                                                | Highlight delivery marker and driver proximity                                                                                               | Redis GEO calculates current distance to delivery point. Trigger arrival suggestion when within configured radius                                                    | PostGIS performs authoritative distance check using geography functions                                      | Server verifies driver is within allowed radius before marking arrived when required                       |
| 19 | Delivery proof stage                     | Show Waiting for Delivery Proof or Proof Submitted. View photos and timestamp                                           | Show Delivery Confirmation in Progress                                        | Show Upload Delivery Proof, OTP and Confirm Delivery actions                                                 | Use camera/gallery upload with compression, retry and upload progress. Store local pending uploads safely                                                          | Keep delivery marker visible. Live tracking may continue until confirmation                                                                  | Redis GEO retains final location temporarily. Remove high-frequency tracking after successful delivery                                                               | Save proof metadata, object-storage path, OTP result, delivery coordinates and timestamp                     | API validates files, OTP, role, state and delivery proximity                                               |
| 20 | Dispatch `DELIVERED`                     | Show Delivered with proof, time, quantities and driver details                                                          | Show Delivered. Actions: Rate Order, Report Issue, View PDF                   | Show Trip Completed with summary. Disable tracking and trip actions                                          | Stop background location service. Clear active-trip local state and refresh history                                                                                | Show final delivered location and completed route summary if available                                                                       | Remove driver from active GEO set or let key expire immediately. Clear active-trip Redis mapping                                                                     | Store final delivery status, delivered_at and completion metadata. Keep permanent delivery coordinates       | Delivery should be idempotent. Trigger order completion when business rules are satisfied                  |
| 21 | Order `COMPLETED`                        | Show Order Completed. Display fulfilment summary, dispatch history, proof and rating                                    | Show Completed. Display delivered quantities and Rate Order action            | Show completed trip in Trip History only                                                                     | Customer rating component becomes available. Owner page becomes read-only except archive/reporting actions                                                         | Live tracking hidden. Static delivery summary may remain                                                                                     | No active GEO state                                                                                                                                                  | Order status becomes `COMPLETED`. Preserve whether fulfilment was full or partial                            | Completion should normally follow delivery rather than loading                                             |
| 22 | Dispatch `CANCELLED` before dispatch     | Show Dispatch Cancelled. Option to create replacement dispatch if order remains loaded                                  | Show “Dispatch is being rearranged,” not necessarily “Order Cancelled”        | Show Trip Cancelled and remove from active trips                                                             | Invalidate all dispatch and active-trip providers                                                                                                                  | Remove active driver marker from customer/owner map                                                                                          | Remove active-trip Redis keys and GEO entries immediately                                                                                                            | Store cancellation reason, actor and timestamp                                                               | Allow only from permitted states and require reason                                                        |
| 23 | Order `CANCELLED`                        | Show Order Cancelled with reason and actor                                                                              | Show Order Cancelled with reason                                              | Nothing unless a linked dispatch existed                                                                     | Hide operational actions. Keep read-only history                                                                                                                   | Hide route and tracking                                                                                                                      | Clear related cache and active-trip keys where applicable                                                                                                            | Preserve order through soft delete or cancelled status                                                       | Block cancellation after loaded/dispatch stages unless explicit exception workflow exists                  |
| 24 | Quotation or Order deleted               | Remove from normal list. Admin/audit may still access it                                                                | Nothing                                                                       | Nothing                                                                                                      | Filter deleted records from normal repositories                                                                                                                    | No map                                                                                                                                       | Invalidate cache entries                                                                                                                                             | Prefer soft deletion with `deleted_at`, `deleted_by`, `deletion_reason`                                      | API must validate deletion rules and preserve audit history                                                |

---

# 4. Exact UI for the Current Example

Current DB snapshot:

```text
Quotation = CONVERTED
Order = LOADED
Dispatch = ACCEPTED
```

## Owner / Manager

Show:

```text
Order Loaded
Driver Accepted
Awaiting Dispatch
```

Primary action:

```text
Mark as Dispatched
```

Secondary actions:

```text
View Dispatch
View Driver
View Vehicle
Call Driver
Cancel Dispatch
```

Do not show:

```text
Create Dispatch
Start Journey
Complete Order
Delivered
```

## Customer

Show:

```text
Loading Completed
Driver Assigned
Awaiting Dispatch
```

Recommended message:

```text
Loading is complete and a driver has accepted the delivery.
The nursery is preparing to dispatch your order.
```

Do not show:

```text
On the Way
Live Tracking
Delivered
```

## Driver

Show:

```text
Trip Accepted
Loading Completed
Waiting for Nursery Dispatch Confirmation
```

Do not show:

```text
Start Journey
In Transit
Reached Destination
```

The Start Journey button should appear only after:

```text
Dispatch = DISPATCHED
```

---

# 5. Flutter / Dart Architecture Expectations

## Recommended structure

```text
Presentation
  Screens
  Widgets
  Notifiers / Controllers

Domain
  Models
  Enums
  Use-case rules

Data
  Repositories
  API clients
  DTOs
  Local storage
```

Existing GreenRoot architecture should continue using:

```text
Riverpod
Dio
Repository pattern
Provider-based dependency injection
```

Do not call:

```dart
ApiClient.instance
```

directly from screens.

Screens should use repositories or notifiers through Riverpod providers.

Example:

```dart
final orderDetailProvider =
    FutureProvider.family<Order, String>((ref, orderId) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrder(orderId);
});
```

## UI state requirements

Every state-based page should support:

```text
Loading
Success
Empty
Error
Retry
Permission denied
Offline
Stale cached data
```

Do not render buttons by checking display text.

Use canonical enum values:

```dart
switch (dispatch.status) {
  case DispatchStatus.pending:
  case DispatchStatus.accepted:
  case DispatchStatus.dispatched:
  case DispatchStatus.inTransit:
  case DispatchStatus.delivered:
  case DispatchStatus.cancelled:
}
```

All buttons must be based on:

```text
Current entity status
Current user role
Nursery membership
Entity ownership
Assignment
Subscription permissions
API capabilities
```

The API remains authoritative.

---

# 6. Mobile Provider Refresh Rules

After a successful mutation, refresh all impacted providers.

Example after driver accepts dispatch:

```text
Dispatch detail
Driver active trip
Owner order detail
Owner dispatch list
Customer order detail
Notifications
```

Example Riverpod pattern:

```dart
await repository.acceptDispatch(dispatchId);

ref.invalidate(dispatchDetailProvider(dispatchId));
ref.invalidate(activeDriverTripProvider);
ref.invalidate(orderDetailProvider(orderId));
ref.invalidate(myDispatchesProvider);
```

Avoid requiring logout/login or app restart to see updated statuses.

---

# 7. Map Display Rules

## Map provider

Use:

```text
OpenStreetMap
```

GreenRoot does not need to purchase Google Maps API for V1.

The app may redirect users to an external navigation app using coordinates.

Example:

```text
Open in Google Maps
Open in Apple Maps
Open in browser
```

## Markers

During `IN_TRANSIT`, show:

| Marker          | Meaning                 |
| --------------- | ----------------------- |
| Driver marker   | Latest driver location  |
| Loading marker  | Nursery/loading point   |
| Delivery marker | Customer delivery point |

## Marker visibility by state

| State           | Owner                                            | Customer                  | Driver                      |
| --------------- | ------------------------------------------------ | ------------------------- | --------------------------- |
| Before dispatch | Loading and delivery preview                     | Usually no map            | No map                      |
| `PENDING`       | Loading + delivery                               | Optional delivery summary | Trip preview after scan     |
| `ACCEPTED`      | Loading + delivery + assigned driver information | Optional static map       | Loading + delivery          |
| `DISPATCHED`    | Driver current location if available             | Static dispatch map       | Driver + loading + delivery |
| `IN_TRANSIT`    | Live driver location                             | Live tracking             | Full navigation map         |
| `DELIVERED`     | Final delivery location                          | Delivery summary          | Completed trip map          |

---

# 8. Redis Responsibilities

Redis should be used for fast-changing, temporary data.

Recommended uses:

```text
Latest driver location
Active trip lookup
Driver-to-trip mapping
Short-lived QR/token validation
Location update throttling
Rate limiting
Notification/event fan-out
Temporary workflow locks
Cached frequently accessed summaries
```

Redis must not be the permanent source of truth for:

```text
Quotation
Order
Dispatch
Delivery proof
Final trip history
Customer details
Financial values
Audit history
```

---

# 9. Redis GEO Design

## Suggested GEO key

```text
geo:active_drivers
```

Member:

```text
driver_user_id or active_trip_id
```

Example conceptual commands:

```text
GEOADD geo:active_drivers longitude latitude driver_id
GEOPOS geo:active_drivers driver_id
GEODIST geo:active_drivers driver_id destination_marker
```

Because the delivery point may not be stored in the same GEO set, application code may use coordinates returned from Redis and calculate or verify distance using PostGIS.

## Supporting Redis keys

```text
driver:active_trip:{driver_id}
trip:driver:{trip_id}
trip:last_location:{trip_id}
trip:location_timestamp:{trip_id}
```

Use TTLs so abandoned trips do not leave stale active data.

Example:

```text
TTL = 15 to 60 minutes
```

Refresh TTL whenever a valid location update arrives.

After delivery or cancellation:

```text
Remove driver from GEO set
Delete active-trip mapping
Delete temporary trip-location keys
```

---

# 10. PostGIS Responsibilities

PostGIS should be used for durable geospatial business data.

Store:

```text
Nursery location
Loading location
Delivery location
Order location
Dispatch pickup point
Dispatch destination point
Final delivery coordinates
Optional sampled driver route history
```

Recommended column type:

```sql
geography(Point, 4326)
```

or:

```sql
geometry(Point, 4326)
```

Use geography when distance in metres is the main requirement.

## Recommended indexes

```sql
CREATE INDEX idx_nursery_location
ON nurseries
USING GIST (location);

CREATE INDEX idx_dispatch_delivery_location
ON dispatches
USING GIST (delivery_location);
```

## Common PostGIS validations

```text
Is driver near loading point?
Is driver near delivery point?
Distance between nursery and customer
Nearby nurseries within 50 km
Nearby market ads
Nearby sourcing requests
Delivery geofence verification
```

Example conceptual query:

```sql
ST_DWithin(
  driver_location,
  delivery_location,
  500
)
```

This checks whether the driver is within 500 metres.

---

# 11. Redis GEO vs PostGIS

| Requirement                    |              Redis GEO |              PostGIS |
| ------------------------------ | ---------------------: | -------------------: |
| Latest live driver location    |                    Yes |             Optional |
| Fast frequent updates          |                    Yes | Not for every second |
| Permanent nursery coordinates  |                     No |                  Yes |
| Permanent delivery coordinates |                     No |                  Yes |
| Nearby nurseries within 50 km  |         Cache possible |                  Yes |
| Driver live distance           |                    Yes |           Can verify |
| Delivery geofence verification | Fast preliminary check |  Authoritative check |
| Historical route               |                     No |       Yes, if needed |
| Spatial reporting              |                     No |                  Yes |

Recommended approach:

```text
Redis GEO = live, fast, temporary
PostGIS = durable, accurate, queryable
```

---

# 12. Driver Location Update Strategy

Do not update location every second.

Recommended V1 behavior:

| Driver condition          |    Update interval |
| ------------------------- | -----------------: |
| App open and moving       |      10–20 seconds |
| App background and moving |      20–60 seconds |
| Driver stationary         |     60–120 seconds |
| Trip not `IN_TRANSIT`     | No active tracking |
| Trip completed/cancelled  |      Stop tracking |

Also consider distance-based updates:

```text
Send update only after moving 30–100 metres
```

Use both time and distance thresholds.

Example logic:

```dart
if (distanceMoved >= 50 || elapsedSeconds >= 30) {
  await locationRepository.updateTripLocation(...);
}
```

---

# 13. Location Permissions

Before `Start Journey`, Flutter should verify:

```text
Location service enabled
Foreground location permission granted
Background location permission granted when required
Battery optimisation warning where relevant
Internet availability
```

If permission is denied:

```text
Do not start journey silently
Show clear explanation
Provide Open Settings action
Allow retry
```

The API should not mark a trip `IN_TRANSIT` unless required validation passes.

---

# 14. API Location Payload

Suggested request:

```json
{
  "trip_id": "uuid",
  "latitude": 17.123456,
  "longitude": 78.123456,
  "accuracy_meters": 15.4,
  "speed_mps": 8.2,
  "heading": 120,
  "captured_at": "2026-07-14T10:30:00Z"
}
```

API validation should check:

```text
Valid latitude and longitude
Assigned driver
Active dispatch
Dispatch status is IN_TRANSIT
Timestamp is reasonable
Accuracy is acceptable
Movement is not physically impossible
Rate limit is respected
```

---

# 15. Location Storage Strategy

For V1:

```text
Redis GEO stores the latest location
PostgreSQL stores important location events only
```

Important location events may include:

```text
Journey started
Loading location departure
Periodic sample every few minutes
Reached destination
Proof upload location
Final delivered location
```

Do not store every GPS event permanently unless there is a strong business requirement.

---

# 16. Live Tracking UI

## Owner live tracking card

Show:

```text
Driver name
Vehicle number
Current status
Last updated time
Distance remaining
ETA if available
Call Driver
Open Map
```

## Customer live tracking card

Show only appropriate information:

```text
Order on the way
Driver first name or masked name
Vehicle number where appropriate
Last updated
Approximate location
Estimated arrival
```

Do not expose:

```text
Driver personal address
Internal trip UUID
Dispatch QR
Nursery internal notes
Customer details of other orders
```

## Driver journey UI

Show:

```text
Current location
Delivery marker
Distance remaining
Delivery contact
Call customer
Open navigation
Reached destination
Upload proof
Confirm delivery
```

---

# 17. Notifications by State

| Event              | Owner / Manager       | Customer                | Driver                     |
| ------------------ | --------------------- | ----------------------- | -------------------------- |
| Quotation sent     | Optional confirmation | New quotation received  | None                       |
| Quotation accepted | Accepted notification | Confirmation            | None                       |
| Quotation rejected | Rejected with reason  | Confirmation            | None                       |
| Order confirmed    | Confirmation          | Order confirmed         | None                       |
| Loading started    | Internal notification | Loading started         | None                       |
| Loading completed  | Internal confirmation | Loading completed       | None                       |
| Dispatch created   | QR ready              | Dispatch being arranged | None                       |
| Driver accepted    | Driver assigned       | Driver assigned         | Trip accepted              |
| Marked dispatched  | Vehicle departed      | Order dispatched        | Start journey available    |
| Journey started    | In transit            | On the way              | Journey active             |
| Near destination   | Driver arriving       | Driver arriving         | Reach destination reminder |
| Delivered          | Delivery completed    | Delivered / rate order  | Trip completed             |
| Dispatch cancelled | Cancellation alert    | Dispatch rearranged     | Trip cancelled             |

---

# 18. Security and RBAC Rules

## Owner

Can:

```text
View full customer details
Create order
Confirm order
Create dispatch
Mark dispatched
View live location
Cancel permitted dispatch states
```

## Manager

Can operate only when:

```text
Active nursery membership exists
Entity belongs to the manager’s nursery
Operation is allowed by role
Assignment rules permit it
```

Customer details may remain masked according to GreenRoot policy.

## Customer

Can:

```text
View own quotation
Accept/reject own quotation
View own order
Track own delivery
Rate completed order
```

## Driver

Can:

```text
Join valid trip
Accept assigned trip
Start journey after dispatch confirmation
Send own location
Upload delivery proof
Confirm delivery
```

Driver cannot:

```text
Edit quotation
Edit order items
See quotation price unless explicitly needed
See unrelated customer data
Join multiple active trips
```

---

# 19. Important Blocked Transitions

| Invalid attempt                                | Required result                         |
| ---------------------------------------------- | --------------------------------------- |
| Accept expired quotation                       | Block                                   |
| Convert rejected quotation                     | Block                                   |
| Convert quotation twice                        | Block                                   |
| Create second active dispatch                  | Block                                   |
| Driver starts journey from `ACCEPTED`          | Block                                   |
| Driver updates location before `IN_TRANSIT`    | Ignore or block                         |
| Complete order while dispatch is not delivered | Block, except supported pickup workflow |
| Cancel dispatch after delivered                | Block                                   |
| Edit order items after loaded                  | Block                                   |
| Driver joins second active trip                | Block                                   |
| Customer accesses another customer’s order     | Return 403/404                          |
| Redis says active but DB says completed        | DB wins; clean Redis                    |

---

# 20. Error and Recovery Handling

Every mobile page should handle:

```text
API timeout
No internet
Expired JWT
403 RBAC error
402 subscription restriction
409 invalid state transition
Location permission denied
GPS disabled
QR invalid
Trip already joined
Driver already has active trip
Dispatch already exists
Stale mobile state
```

For `409 Conflict`, refresh the entity and show the latest valid state.

Example message:

```text
This order was updated by another user.
The latest status has been refreshed.
```

---

# 21. Future Prompt for Reviewing Existing Implementation

Use the following instruction when asking an AI coding tool to improve the current implementation:

```text
Review the existing GreenRoot quotation, order, loading, dispatch,
driver trip and delivery implementation against the attached lifecycle
specification.

First inspect the existing:

- PostgreSQL schema
- PostGIS columns and indexes
- Redis keys and Redis GEO usage
- Go API routes, handlers, services and repositories
- RBAC and status transition validation
- Flutter/Dart models, enums, repositories, Riverpod providers
- Existing mobile screens and navigation
- OpenStreetMap implementation
- Driver location service
- Notification handling
- Unit, integration and E2E tests

Do not create duplicate APIs, pages, providers, repositories, statuses,
DB columns or Redis keys.

Reuse and improve existing code.

Identify mismatches between DB, API and mobile UI.

Ensure every quotation, order and dispatch state displays the correct
information and actions for Owner/Manager, Customer and Driver.

Use Redis GEO only for live temporary driver location.

Use PostGIS/PostgreSQL as the durable source of truth for nursery,
loading, delivery and final trip coordinates.

Ensure:

- ACCEPTED cannot directly become IN_TRANSIT
- DISPATCHED is required before Start Journey
- Only one active dispatch exists per order
- Only one active trip exists per driver
- Driver location updates are allowed only for the assigned active trip
- Background tracking stops after delivery or cancellation
- Redis active location keys are cleaned after completion
- Order completion normally follows dispatch delivery
- Customer can access only their own order
- Manager masking and nursery membership rules remain intact
- Existing subscription and audit behavior is preserved

For each mismatch:

1. Explain the current behavior.
2. Explain the correct expected behavior.
3. Make the smallest safe fix.
4. Update DB/API/mobile/tests/docs where needed.
5. Run relevant tests.
6. Do not modify unrelated modules.
7. Do not overengineer V1.
```

---

# 22. Final Source-of-Truth Summary

```text
Quotation handles commercial agreement.

Order handles requested and fulfilled plant quantities.

Dispatch handles the vehicle and driver assignment.

Redis GEO handles the latest live driver location.

PostGIS handles permanent spatial business data.

Flutter/Dart displays only actions valid for the current role and state.

The Go API remains authoritative for every transition.

PostgreSQL remains the permanent source of truth.
```
