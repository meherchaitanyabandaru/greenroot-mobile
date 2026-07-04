// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — OWNER HOME SECTION                                              ║
// ║  Role:  NURSERY_OWNER                                                        ║
// ║  Guard: rendered only when caps.isNurseryOwner == true                       ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// CONTEXT
// ───────
// Rendered inside HomeScreen as the main content block for a NURSERY_OWNER.
// The owner's home is a business operations dashboard — orders pipeline,
// loading queue status, pending quotations, dispatch overview, and team summary.
//
// Dispatch condition in home_screen.dart:
//   else if (caps.isNurseryOwner) OwnerHome()
//
// NURSERY CONTEXT
// ────────────────
// All owner operations are scoped to their own nursery:
//   caps.primaryNurseryId  — the nursery ID used in all API calls
//   caps.ownedNurseryId    — same value; use this for /nurseries/:id/* calls
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — WHAT AN OWNER CAN DO                                                │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  View nursery profile + stats      GET /api/v1/nurseries/:id            │
// │  ✅  Update nursery settings           PUT /api/v1/nurseries/:id            │
// │  ✅  Create orders for buyers          POST /api/v1/orders                  │
// │  ✅  View all nursery orders           GET  /api/v1/orders                  │
// │  ✅  Confirm order                     POST /api/v1/orders/:id/confirm       │
// │  ✅  Start loading                     POST /api/v1/orders/:id/start-loading │
// │  ✅  Complete loading                  POST /api/v1/orders/:id/complete-loading│
// │  ✅  Cancel order                      POST /api/v1/orders/:id/cancel        │
// │  ✅  Delete PENDING order              DELETE /api/v1/orders/:id             │
// │  ✅  Manage order items                POST/PUT/DELETE /api/v1/orders/:id/items/:itemId│
// │  ✅  Set loaded quantity per item      PUT /api/v1/orders/:id/items/:itemId/loaded-quantity│
// │  ✅  Create quotations for buyers      POST /api/v1/quotations               │
// │  ✅  View all nursery quotations       GET  /api/v1/quotations               │
// │  ✅  Approve quotation (own)           POST /api/v1/quotations/:id/approve   │
// │  ✅  Convert quotation to order        POST /api/v1/quotations/:id/convert-to-order│
// │  ✅  Delete quotation                  DELETE /api/v1/quotations/:id         │
// │  ✅  Full inventory management         GET/POST /api/v1/nurseries/:id/inventory│
// │        Update/delete items             PUT/DELETE /api/v1/inventory/:id      │
// │  ✅  Plant requests (B2B sourcing)     GET/POST/PUT /api/v1/nurseries/:id/requests│
// │  ✅  Manage dispatches                 GET/POST /api/v1/dispatches           │
// │  ✅  Assign driver to dispatch         POST /api/v1/dispatches/:id/assign-driver│
// │  ✅  View team (managers)              GET /api/v1/nurseries/:id/managers    │
// │  ✅  Invite managers                   POST /api/v1/invites  (MANAGER_INVITE)│
// │  ✅  Invite customers                  POST /api/v1/invites  (CUSTOMER_INVITE)│
// │  ✅  View invite list                  GET /api/v1/nurseries/:id/invites     │
// │  ✅  Sourcing network                  GET /api/v1/sourcing                  │
// │  ✅  Post sourcing request             POST /api/v1/sourcing                 │
// │  ✅  View order-linked payments        GET /api/v1/payments                  │
// │  ✅  Assign manager to order           POST /api/v1/orders/:id/assign-manager│
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — WHAT AN OWNER CANNOT DO                                             │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Modify other nurseries' data (API 403 if :id ≠ own nursery)            │
// │  ❌  Delete CONFIRMED, LOADING, or later-stage orders                        │
// │       (API guard: only PENDING orders deletable)                             │
// │  ❌  Accept/reject quotations as a buyer (POST .../buyer-accept)             │
// │       (Buyers accept; owners approve/convert)                                │
// │  ❌  Edit order items after LOADED / PARTIALLY_FULFILLED / COMPLETED         │
// │       (items are locked post-loading)                                        │
// │  ❌  Become a manager simultaneously (409 conflicting_role)                  │
// │  ❌  Impersonate driver or access vehicle management                         │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// API CALLS — ON LOAD & PULL-TO-REFRESH
// ──────────────────────────────────────
//   1. GET /api/v1/orders?page=1&per_page=10&status=PENDING,CONFIRMED,LOADING
//        → Active orders pipeline count + recent orders list
//
//   2. GET /api/v1/orders?page=1&per_page=5&status=LOADING
//        → Loading queue — show loading progress cards for in-progress loads
//
//   3. GET /api/v1/dispatches?page=1&per_page=5
//        → Outbound dispatch cards (vehicles en route)
//
//   4. GET /api/v1/quotations?page=1&per_page=5&status=DRAFT,CUSTOMER_ACCEPTED
//        → Quotations needing action (unsent drafts + accepted → convert to order)
//
//   5. GET /api/v1/nurseries/:id   (caps.primaryNurseryId)
//        → Nursery summary: name, status, active_orders_count, pending_items_count
//
// ORDER STATUS MACHINE (API-enforced)
// ─────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED | PARTIALLY_FULFILLED → COMPLETED
//   PENDING → CANCELLED  (owner can cancel from PENDING)
//   CONFIRMED → CANCELLED  (owner can cancel from CONFIRMED too)
//   LOADING → cannot cancel; must complete loading first
//
// QUOTATION STATUS MACHINE
// ─────────────────────────
//   DRAFT → APPROVED → SENT | CUSTOMER_SENT → CUSTOMER_ACCEPTED → CONVERTED (→ order)
//                            ↘ CUSTOMER_REJECTED
//                            ↘ EXPIRED
//   DELETE allowed: DRAFT, APPROVED, CUSTOMER_REJECTED, EXPIRED states
//
// NAVIGATION FROM THIS WIDGET
// ────────────────────────────
//   context.push('/orders/:id')            — order detail + action buttons
//   context.push('/orders/:id/loading')    — loading workflow screen
//   context.push('/dispatches/:id')        — dispatch management
//   context.push('/quotations/:id')        — quotation detail + approve/convert
//   context.push('/nursery/members')       — team management (route: _ownerGuard)
//   context.push('/nursery/inventory')     — inventory management (route: _ownerGuard)
//
// BUSINESS RULES — MUST ENFORCE IN UI
// ─────────────────────────────────────
//   • Only show "Delete Order" for PENDING orders — disable/hide for all others
//   • Show "Confirm" button only on PENDING orders
//   • Show "Start Loading" only on CONFIRMED orders
//   • After LOADING state — items are locked; show loaded_quantity progress bars
//   • Quotation "Convert to Order" only when quotation.status == CUSTOMER_ACCEPTED
//   • Team tab: only owner can send MANAGER_INVITE — never show this for managers
//   • Nursery must be ACTIVE status for most operations; show warning if PENDING/SUSPENDED
//
// SEE ALSO
// ─────────
//   lib/features/owner/owner_tab.dart           — full selling tab content
//   lib/features/owner/owner_members_screen.dart — team management screen
//   lib/features/selling/selling_screen.dart     — role wrapper (routes here)

import 'package:flutter/material.dart';

/// Owner home section rendered inside HomeScreen for nursery owners.
///
/// Empty placeholder — implement using the RBAC and API spec in the file header.
/// Build: nursery KPIs banner, active orders list, loading queue, dispatch cards,
/// quotations needing action, quick-access to team and inventory.
class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
