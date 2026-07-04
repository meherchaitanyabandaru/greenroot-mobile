// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — BUYER HOME SECTION                                              ║
// ║  Role:  BUYER (customer)                                                     ║
// ║  Guard: rendered only when !caps.canSell && !caps.isDriverOnly               ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// CONTEXT
// ───────
// Rendered inside HomeScreen as the main content block when the logged-in user
// is a BUYER — i.e. a GreenRoot user who is NOT a nursery owner, NOT a manager,
// and NOT a driver. This is the buyer's "dashboard" for the purchase lifecycle:
//
//   BROWSE  →  /plants, /nurseries
//   RECEIVE →  quotations sent by nurseries (buyer accepts / rejects)
//   TRACK   →  order status + dispatch live location
//
// Dispatch condition in home_screen.dart (HomeScreen.build):
//   else BuyerHome()   ← fallback when all other role checks are false
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — WHAT A BUYER CAN DO                                                 │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  Browse plant catalog              GET  /api/v1/plants                  │
// │  ✅  Browse nurseries (public)         GET  /api/v1/nurseries               │
// │  ✅  View nursery detail               GET  /api/v1/nurseries/:id           │
// │  ✅  View own orders                   GET  /api/v1/orders                  │
// │  ✅  View order detail                 GET  /api/v1/orders/:id              │
// │  ✅  Cancel PENDING order (own only)   POST /api/v1/orders/:id/cancel       │
// │  ✅  View quotations (nursery→buyer)   GET  /api/v1/quotations              │
// │  ✅  View quotation detail             GET  /api/v1/quotations/:id          │
// │  ✅  Accept a quotation                POST /api/v1/quotations/:id/buyer-accept  │
// │  ✅  Reject a quotation                POST /api/v1/quotations/:id/buyer-reject  │
// │  ✅  Track own dispatches              GET  /api/v1/dispatches              │
// │  ✅  Live dispatch tracking            GET  /api/v1/dispatches/:id/track    │
// │  ✅  View own payment history          GET  /api/v1/payments                │
// │  ✅  Manage delivery addresses         GET/POST/PUT/DELETE                  │
// │                                         /api/v1/users/:id/addresses         │
// │  ✅  Register nursery application      POST /api/v1/nurseries               │
// │         (becomes nursery owner on admin approval; normal buyer flow)        │
// │  ✅  Accept customer/team invite       POST /api/v1/invites/:uuid/accept    │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — WHAT A BUYER CANNOT DO                                              │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Create orders     POST /api/v1/orders   — nursery staff creates orders │
// │  ❌  Create quotations POST /api/v1/quotations — nursery → buyer flow only  │
// │  ❌  Approve quotations     POST .../approve                                │
// │  ❌  Convert quotations     POST .../convert-to-order                       │
// │  ❌  Access inventory       ANY  /api/v1/nurseries/:id/inventory            │
// │  ❌  Access plant requests  ANY  /api/v1/nurseries/:id/requests             │
// │  ❌  Access sourcing network GET /api/v1/sourcing                           │
// │  ❌  Create dispatches      POST /api/v1/dispatches                         │
// │  ❌  Assign drivers         POST /api/v1/dispatches/:id/assign-driver       │
// │  ❌  Invite managers        POST /api/v1/invites  (MANAGER_INVITE type)     │
// │  ❌  Cancel non-PENDING orders — status must be exactly PENDING             │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// API CALLS — ON LOAD & PULL-TO-REFRESH
// ──────────────────────────────────────
//   1. GET /api/v1/quotations?page=1&per_page=5&status=APPROVED,SENT,CUSTOMER_SENT
//        → "X offers waiting" badge card at top of home
//        → Response: { data: [quotation...], pagination: { page, per_page, total, total_pages } }
//        → quotation fields: id, quotation_number, status, total_amount,
//                            nursery_name, created_at, items[]
//
//   2. GET /api/v1/orders?page=1&per_page=5
//        → Active order card (most recent non-COMPLETED / non-CANCELLED order)
//        → Response: { data: [order...], pagination: {...} }
//        → order fields: id, order_number, status, total_amount, nursery_name, created_at
//
//   3. GET /api/v1/dispatches?page=1&per_page=3
//        → Live delivery card when a dispatch is IN_TRANSIT
//        → Response: { data: [dispatch...], pagination: {...} }
//        → dispatch fields: id, dispatch_number, status, vehicle_number, driver_name,
//                           estimated_arrival, order_id
//
// ORDER STATUS VALUES (state machine — API enforced)
// ───────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED | PARTIALLY_FULFILLED → COMPLETED
//                                                                 ↘ CANCELLED (only from PENDING)
//
// QUOTATION STATUS VALUES
// ────────────────────────
//   DRAFT → APPROVED → SENT | CUSTOMER_SENT → CUSTOMER_ACCEPTED | CUSTOMER_REJECTED
//                                            → CONVERTED (when nursery converts to order)
//                                            → EXPIRED
//
// NAVIGATION FROM THIS WIDGET
// ────────────────────────────
//   context.push('/quotations/:id')        — quotation detail + accept/reject actions
//   context.push('/orders/:id')            — order detail + cancel button (PENDING only)
//   context.push('/dispatches/:id/track')  — live delivery map
//   context.push('/plants')               — browse plant catalog
//   context.push('/nurseries')            — browse and explore nurseries
//
// BUSINESS RULES — MUST ENFORCE IN UI
// ─────────────────────────────────────
//   • NEVER render "Create Order", "Place Order", "Buy Now" button or FAB
//   • "Accept / Reject" buttons visible ONLY when quotation.status ∈
//     { APPROVED, SENT, CUSTOMER_SENT }
//   • "Cancel Order" visible ONLY when order.status == 'PENDING'
//   • Orders in LOADING, LOADED, PARTIALLY_FULFILLED, COMPLETED are immutable;
//     show read-only status badge, no action buttons
//   • Empty state: show "Explore nurseries →" CTA, NOT "Create your first order"
//   • If pending_quotations > 0, show a prominent "You have N offers" banner
//     at the very top above the orders list
//   • Label incoming quotations as "Offers from nurseries" — buyer did not create them

import 'package:flutter/material.dart';

/// Buyer home section rendered inside HomeScreen for buyer-only users.
///
/// Empty placeholder — implement using the API and RBAC spec in the file header.
/// See also: [BuyerTab] for the Buying tab content, [BuyerPaymentsScreen] for
/// payment history, and `router.dart` for route guards (_buyerGuard).
class BuyerHome extends StatelessWidget {
  const BuyerHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
