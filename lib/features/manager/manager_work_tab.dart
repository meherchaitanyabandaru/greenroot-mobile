// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — MANAGER WORK TAB                                                ║
// ║  Role:  MANAGER (Gumastha)                                                   ║
// ║  Entry: BuyingScreen → ManagerWorkTab  /  SellingScreen → ManagerWorkTab    ║
// ║  Guard: caps.isManager == true (enforced in wrapper screens)                 ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// PURPOSE
// ───────
// The full operational tab screen for MANAGER role — shown in both the "Buying"
// tab and the "Work" tab positions in MainShell. Managers are nursery employees
// who handle day-to-day operations: order processing, loading workflow, dispatch
// creation, and quotation management.
//
// CRITICAL BUSINESS RULE — MANAGER ≠ OWNER
// ─────────────────────────────────────────
//   Manager and nursery owner are MUTUALLY EXCLUSIVE roles.
//   A manager cannot own a nursery (API returns 409 conflicting_role).
//   Therefore this tab must NEVER show owner-exclusive actions.
//
// NURSERY CONTEXT
// ────────────────
//   caps.primaryNurseryId — nursery the manager is assigned to
//   All nursery-scoped calls use this ID
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — FULL PERMISSION SET FOR THIS TAB                                    │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │                                                                             │
// │  ORDERS (operational access)                                                │
// │  ✅  List nursery orders               GET    /api/v1/orders                │
// │        Params: page, per_page, status                                       │
// │  ✅  Order detail                      GET    /api/v1/orders/:id            │
// │  ✅  Create order for buyer            POST   /api/v1/orders                │
// │        Body: { nursery_id, buyer_id, delivery_address_id, items[], notes? } │
// │  ✅  Update order (pre-confirm only)   PUT    /api/v1/orders/:id            │
// │  ✅  Confirm order (PENDING→CONFIRMED) POST   /api/v1/orders/:id/confirm    │
// │  ✅  Cancel order (PENDING/CONFIRMED)  POST   /api/v1/orders/:id/cancel     │
// │  ✅  Add item to order                 POST   /api/v1/orders/:id/items      │
// │        Body: { plant_id, quantity, unit_price }                             │
// │  ✅  Update order item                 PUT    /api/v1/orders/:id/items/:itemId│
// │  ✅  Remove order item                 DELETE /api/v1/orders/:id/items/:itemId│
// │  ✅  Start loading (CONFIRMED→LOADING) POST   /api/v1/orders/:id/start-loading│
// │  ✅  Set loaded quantity per item      PUT    /api/v1/orders/:id/items/:itemId/loaded-quantity│
// │        Body: { loaded_quantity: int }                                       │
// │  ✅  Complete loading                  POST   /api/v1/orders/:id/complete-loading│
// │                                                                             │
// │  QUOTATIONS                                                                 │
// │  ✅  List quotations                   GET    /api/v1/quotations            │
// │  ✅  Quotation detail                  GET    /api/v1/quotations/:id        │
// │  ✅  Create quotation for buyer        POST   /api/v1/quotations            │
// │        Body: { nursery_id, buyer_id, items[], valid_until?, notes? }        │
// │  ✅  Approve quotation                 POST   /api/v1/quotations/:id/approve│
// │  ✅  Convert accepted quotation→order  POST   /api/v1/quotations/:id/convert-to-order│
// │        Guard: quotation.status must be CUSTOMER_ACCEPTED                    │
// │                                                                             │
// │  INVENTORY (READ-ONLY)                                                      │
// │  ✅  List inventory                    GET    /api/v1/nurseries/:id/inventory│
// │        Use for plant lookup when creating orders / quotations               │
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
// │  INVITES                                                                    │
// │  ✅  Invite customer                   POST   /api/v1/invites               │
// │        Body: { nursery_id, invite_type: "CUSTOMER_INVITE", mobile/email }  │
// │                                                                             │
// │  SOURCING NETWORK                                                           │
// │  ✅  Browse sourcing posts             GET    /api/v1/sourcing              │
// │  ✅  Create plant request              POST   /api/v1/nurseries/:id/requests│
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — FORBIDDEN (must not appear anywhere in this tab)                    │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Delete orders       DELETE /api/v1/orders/:id           — owner only   │
// │  ❌  Delete quotations   DELETE /api/v1/quotations/:id       — owner only   │
// │  ❌  Add inventory       POST   /api/v1/nurseries/:id/inventory — owner only│
// │  ❌  Edit inventory      PUT    /api/v1/inventory/:id         — owner only  │
// │  ❌  Delete inventory    DELETE /api/v1/inventory/:id         — owner only  │
// │  ❌  Invite managers     POST   /api/v1/invites (MANAGER_INVITE) — owner only│
// │  ❌  View team list      GET    /api/v1/nurseries/:id/managers — owner only │
// │  ❌  Update nursery      PUT    /api/v1/nurseries/:id          — owner only │
// │  ❌  Register nursery    POST   /api/v1/nurseries  (409 conflict guaranteed)│
// │  ❌  /nursery/members route — _ownerGuard blocks; redirect to /home         │
// │  ❌  /inventory/add route — _ownerGuard blocks; redirect to /home           │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// TAB STRUCTURE (suggested sub-navigation within ManagerWorkTab)
// ──────────────────────────────────────────────────────────────
//   Section 1: Work Queue — PENDING orders needing confirmation
//   Section 2: Loading    — CONFIRMED orders ready to start loading
//                         — LOADING orders in progress (item-by-item qty entry)
//   Section 3: Dispatches — create dispatch for LOADED orders + assign driver
//   Section 4: Quotations — draft + accepted quotations needing action
//   Section 5: Inventory  — READ-ONLY browse; link to order/quotation item picker
//
// LOADING WORKFLOW (manager's primary task)
// ──────────────────────────────────────────
//   1. Order arrives in CONFIRMED state
//   2. Manager taps "Start Loading" → POST /api/v1/orders/:id/start-loading
//      → order.status becomes LOADING
//   3. Manager enters loaded_quantity for each item one-by-one:
//      PUT /api/v1/orders/:id/items/:itemId/loaded-quantity
//      Body: { loaded_quantity: int }  (must be ≤ ordered_quantity)
//   4. Manager taps "Complete Loading" → POST /api/v1/orders/:id/complete-loading
//      → order.status becomes LOADED (all items) or PARTIALLY_FULFILLED (some short)
//   5. Manager creates dispatch for the loaded order:
//      POST /api/v1/dispatches  Body: { order_id, vehicle_id }
//   6. Manager assigns driver: POST /api/v1/dispatches/:id/assign-driver
//      → Driver receives the trip notification
//
// ORDER STATUS MACHINE
// ─────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED           → COMPLETED
//                                 → PARTIALLY_FULFILLED → COMPLETED
//   PENDING or CONFIRMED → CANCELLED  (manager can cancel these states)
//
// QUOTATION STATUS MACHINE
// ─────────────────────────
//   DRAFT → APPROVED → SENT | CUSTOMER_SENT → CUSTOMER_ACCEPTED → CONVERTED
//                                           → CUSTOMER_REJECTED
//                                           → EXPIRED
//   Manager can: create (DRAFT), approve, convert (CUSTOMER_ACCEPTED only)
//   Manager CANNOT: delete quotations (owner privilege)
//
// PAGINATION PATTERN
// ───────────────────
//   All list responses: { data: T[], pagination: { page, per_page, total, total_pages } }
//   Use ApiPagination from lib/core/models/pagination.dart
//
// ERROR HANDLING
// ───────────────
//   403 forbidden       — not assigned to this nursery, or owner-only action
//   409 conflict        — invalid state transition (e.g. start loading on PENDING order)
//   422 unprocessable   — loaded_quantity > ordered_quantity
//
// FAB (from main_shell.dart _buildFab for manager role)
// ──────────────────────────────────────────────────────
//   Manager FAB options: "New Order", "New Quotation", "New Dispatch"
//   These are managed in MainShell — do NOT duplicate in ManagerWorkTab
//
// NAVIGATION
// ───────────
//   context.push('/orders/:id')         — order detail + action buttons
//   context.push('/orders/:id/loading') — loading workflow (per-item qty entry)
//   context.push('/quotations/:id')     — quotation detail + approve/convert
//   context.push('/dispatches/:id')     — dispatch detail + assign driver
//   context.push('/plants')             — plant catalog (for order/quotation item lookup)
//
// SEE ALSO
// ─────────
//   lib/features/manager/manager_home.dart       — home section summary
//   lib/features/buying/buying_screen.dart        — role wrapper (routes here as "Buying" tab)
//   lib/features/selling/selling_screen.dart      — role wrapper (routes here as "Work" tab)

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Manager Work tab — operational hub for MANAGER role users.
///
/// Empty placeholder — implement using the RBAC and API spec in the file header.
/// Build: work queue (orders), loading workflow, dispatch creation, quotations.
/// Inventory is READ-ONLY. Team management is NOT available (owner-only).
class ManagerWorkTab extends StatelessWidget {
  const ManagerWorkTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
          child: Text('Manager — Work Tab', style: AppTypography.h3)),
    );
  }
}
