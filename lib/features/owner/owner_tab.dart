// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — OWNER TAB  (Selling tab content for NURSERY_OWNER)             ║
// ║  Role:  NURSERY_OWNER                                                        ║
// ║  Entry: SellingScreen → OwnerTab   /  BuyingScreen → OwnerTab               ║
// ║  Guard: caps.isNurseryOwner == true (enforced in wrapper screens)            ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// PURPOSE
// ───────
// The full content of the "Selling" tab (and also the "Buying" tab when owner
// has both roles active) in MainShell for nursery owners. This is the complete
// nursery operations centre — orders, quotations, inventory, loading, dispatch,
// team management, sourcing, and customer management.
//
// NURSERY CONTEXT
// ────────────────
// All calls use caps.primaryNurseryId as the nursery scope.
// Read caps from: ref.watch(sessionProvider).capabilities
//   caps.primaryNurseryId  — nursery ID for /nurseries/:id/* endpoints
//   caps.ownedNurseryId    — same; present only for owners
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — FULL PERMISSION SET FOR THIS TAB                                    │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │                                                                             │
// │  ORDERS                                                                     │
// │  ✅  List nursery orders               GET    /api/v1/orders                │
// │        Params: page, per_page, status (filter)                              │
// │  ✅  Order detail                      GET    /api/v1/orders/:id            │
// │  ✅  Create order for buyer            POST   /api/v1/orders                │
// │        Body: { nursery_id, buyer_id, delivery_address_id, items[], notes? } │
// │  ✅  Update order                      PUT    /api/v1/orders/:id            │
// │  ✅  Delete PENDING order              DELETE /api/v1/orders/:id            │
// │  ✅  Confirm order                     POST   /api/v1/orders/:id/confirm    │
// │  ✅  Cancel order (PENDING/CONFIRMED)  POST   /api/v1/orders/:id/cancel     │
// │  ✅  Assign manager to order           POST   /api/v1/orders/:id/assign-manager│
// │  ✅  Add item to order                 POST   /api/v1/orders/:id/items      │
// │        Body: { plant_id, quantity, unit_price }                             │
// │  ✅  Update order item                 PUT    /api/v1/orders/:id/items/:itemId│
// │  ✅  Remove order item                 DELETE /api/v1/orders/:id/items/:itemId│
// │  ✅  Start loading (CONFIRMED→LOADING) POST   /api/v1/orders/:id/start-loading│
// │  ✅  Set loaded quantity per item      PUT    /api/v1/orders/:id/items/:itemId/loaded-quantity│
// │        Body: { loaded_quantity: int }                                       │
// │  ✅  Complete loading (→LOADED)        POST   /api/v1/orders/:id/complete-loading│
// │                                                                             │
// │  QUOTATIONS                                                                 │
// │  ✅  List quotations                   GET    /api/v1/quotations            │
// │  ✅  Quotation detail                  GET    /api/v1/quotations/:id        │
// │  ✅  Create quotation for buyer        POST   /api/v1/quotations            │
// │        Body: { nursery_id, buyer_id, items[], valid_until?, notes? }        │
// │  ✅  Approve quotation                 POST   /api/v1/quotations/:id/approve│
// │  ✅  Convert accepted quotation→order  POST   /api/v1/quotations/:id/convert-to-order│
// │        Guard: quotation.status must be CUSTOMER_ACCEPTED                    │
// │  ✅  Delete quotation                  DELETE /api/v1/quotations/:id        │
// │        Guard: DRAFT, APPROVED, CUSTOMER_REJECTED, EXPIRED only              │
// │                                                                             │
// │  INVENTORY                                                                  │
// │  ✅  List inventory                    GET    /api/v1/nurseries/:id/inventory│
// │  ✅  Add inventory item                POST   /api/v1/nurseries/:id/inventory│
// │        Body: { plant_id, available_quantity, unit_price, unit?, description?}│
// │  ✅  Update inventory item             PUT    /api/v1/inventory/:id         │
// │  ✅  Delete inventory item             DELETE /api/v1/inventory/:id         │
// │                                                                             │
// │  PLANT REQUESTS (B2B sourcing)                                              │
// │  ✅  List plant requests               GET    /api/v1/nurseries/:id/requests│
// │  ✅  Create plant request              POST   /api/v1/nurseries/:id/requests│
// │  ✅  Update plant request status       PUT    /api/v1/nurseries/:id/requests/:requestId│
// │                                                                             │
// │  DISPATCHES                                                                 │
// │  ✅  List dispatches                   GET    /api/v1/dispatches            │
// │  ✅  Dispatch detail                   GET    /api/v1/dispatches/:id        │
// │  ✅  Create dispatch                   POST   /api/v1/dispatches            │
// │        Body: { order_id, vehicle_id, driver_id?, notes? }                  │
// │  ✅  Assign driver to dispatch         POST   /api/v1/dispatches/:id/assign-driver│
// │        Body: { driver_id }                                                  │
// │  ✅  Live dispatch tracking            GET    /api/v1/dispatches/:id/track  │
// │                                                                             │
// │  TEAM & CUSTOMERS (→ owner_members_screen.dart)                             │
// │  ✅  List managers                     GET    /api/v1/nurseries/:id/managers│
// │  ✅  List invites                      GET    /api/v1/nurseries/:id/invites │
// │  ✅  Invite manager                    POST   /api/v1/invites               │
// │        Body: { nursery_id, invite_type: "MANAGER_INVITE", mobile/email }    │
// │  ✅  Invite customer                   POST   /api/v1/invites               │
// │        Body: { nursery_id, invite_type: "CUSTOMER_INVITE", mobile/email }  │
// │                                                                             │
// │  SOURCING NETWORK                                                           │
// │  ✅  Browse sourcing posts             GET    /api/v1/sourcing              │
// │  ✅  Create sourcing request           POST   /api/v1/sourcing              │
// │  ✅  View nursery connections          GET    /api/v1/connections           │
// │                                                                             │
// │  PAYMENTS                                                                   │
// │  ✅  View order-linked payments        GET    /api/v1/payments              │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — FORBIDDEN                                                           │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Delete CONFIRMED/LOADING/LOADED orders — API returns 409               │
// │  ❌  Edit items on LOADED/PARTIALLY_FULFILLED/COMPLETED orders               │
// │  ❌  Accept quotations as buyer (POST .../buyer-accept) — owner role only   │
// │  ❌  Convert quotation when status ≠ CUSTOMER_ACCEPTED — API 409            │
// │  ❌  Access other nurseries' data — API 403                                 │
// │  ❌  Manage vehicles (admin-only route)                                     │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// TAB STRUCTURE (suggested sub-navigation within OwnerTab)
// ─────────────────────────────────────────────────────────
//   Section 1: Orders     — pipeline view: PENDING, CONFIRMED, LOADING, LOADED
//   Section 2: Quotations — draft, sent, accepted, expired
//   Section 3: Dispatches — outbound + in-transit
//   Section 4: Inventory  — stock list + add/edit actions
//   Section 5: Team       — navigates to /nursery/members (owner_members_screen)
//   Section 6: Sourcing   — B2B plant requests + sourcing network
//
// ORDER STATUS MACHINE (must replicate in UI button visibility)
// ──────────────────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED           → COMPLETED
//                                 → PARTIALLY_FULFILLED → COMPLETED
//   PENDING or CONFIRMED → CANCELLED  (owner can cancel these)
//   LOADING state: items locked; only loaded_quantity updates allowed
//
// QUOTATION STATUS MACHINE
// ─────────────────────────
//   DRAFT → APPROVED → SENT | CUSTOMER_SENT
//                            → CUSTOMER_ACCEPTED  → (owner converts) → CONVERTED
//                            → CUSTOMER_REJECTED
//                            → EXPIRED
//
// PAGINATION PATTERN
// ───────────────────
//   All list responses: { data: T[], pagination: { page, per_page, total, total_pages } }
//   Use ApiPagination from lib/core/models/pagination.dart
//
// ERROR HANDLING
// ───────────────
//   403 forbidden       — nursery_id mismatch (trying to edit another nursery)
//   404 not_found       — order/quotation/dispatch no longer exists
//   409 conflict        — invalid state transition (e.g. confirm a cancelled order)
//   422 unprocessable   — validation failure (e.g. loaded_quantity > ordered_quantity)
//
// FAB (from main_shell.dart _buildFab)
// ─────────────────────────────────────
//   Owner FAB options: "New Order", "New Quotation", "Plant Request"
//   These FABs are managed in MainShell — do NOT duplicate in OwnerTab
//
// NAVIGATION
// ───────────
//   context.push('/orders/:id')         — order detail
//   context.push('/orders/:id/loading') — loading workflow (start-loading → loaded-qty → complete)
//   context.push('/quotations/:id')     — quotation detail + actions
//   context.push('/dispatches/:id')     — dispatch detail + assign driver
//   context.push('/nursery/inventory')  — inventory management (route: _ownerGuard)
//   context.push('/nursery/members')    — team management (route: _ownerGuard)
//   context.push('/inventory/add')      — add inventory item (route: _ownerGuard)
//
// SEE ALSO
// ─────────
//   lib/features/owner/owner_home.dart            — home section summary dashboard
//   lib/features/owner/owner_members_screen.dart  — team management (MembersScreen)
//   lib/features/selling/selling_screen.dart       — role wrapper (routes here)

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Owner Selling tab — full nursery operations for NURSERY_OWNER role.
///
/// Empty placeholder — implement using the RBAC and API spec in the file header.
/// Build: orders pipeline, quotations, dispatches, inventory, team, sourcing.
class OwnerTab extends StatelessWidget {
  const OwnerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body:
          Center(child: Text('Owner — Selling Tab', style: AppTypography.h3)),
    );
  }
}
