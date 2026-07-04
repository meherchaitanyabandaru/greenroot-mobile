// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — BUYER TAB  (Buying tab content for BUYER role)                 ║
// ║  Role:  BUYER (customer)                                                     ║
// ║  Entry: BuyingScreen → BuyerTab (when !caps.canSell && !caps.isDriverOnly)  ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// PURPOSE
// ───────
// The full content of the "Buying" tab in MainShell for buyer-only users.
// This is the buyer's primary transaction hub — NOT for creating orders.
// Buyers receive quotations from nurseries and respond (accept / reject).
// Orders are created by nursery staff; buyers are linked to them automatically.
//
// TAB STRUCTURE (suggested)
// ─────────────────────────
//   Tab 1: "Offers"   — quotations sent by nurseries awaiting buyer response
//   Tab 2: "Orders"   — buyer's order list with status tracking
//   Tab 3: "Deliveries" — dispatches for buyer's orders
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — ALLOWED ACTIONS IN THIS TAB                                         │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  View quotations (from nursery to buyer)                                │
// │        GET  /api/v1/quotations                                              │
// │        Query params: page, per_page, status (filter by quotation status)    │
// │                                                                             │
// │  ✅  View quotation detail                                                  │
// │        GET  /api/v1/quotations/:id                                          │
// │        Response: id, quotation_number, status, total_amount, nursery_name, │
// │                  items[{ plant_name, quantity, unit_price, total }],         │
// │                  delivery_address, created_at, expires_at                   │
// │                                                                             │
// │  ✅  Accept a quotation (buyer consent)                                     │
// │        POST /api/v1/quotations/:id/buyer-accept                             │
// │        Allowed status: APPROVED | SENT | CUSTOMER_SENT                      │
// │        Side-effect: quotation.status → CUSTOMER_ACCEPTED                   │
// │        After accept: nursery staff converts to order (buyer cannot)         │
// │                                                                             │
// │  ✅  Reject a quotation                                                     │
// │        POST /api/v1/quotations/:id/buyer-reject                             │
// │        Body: { reason?: string }   (optional rejection note)                │
// │        Allowed status: APPROVED | SENT | CUSTOMER_SENT                      │
// │        Side-effect: quotation.status → CUSTOMER_REJECTED                   │
// │                                                                             │
// │  ✅  View own orders                                                        │
// │        GET  /api/v1/orders                                                  │
// │        Query params: page, per_page                                         │
// │        Response: { data: [order...], pagination: {...} }                    │
// │        Fields: id, order_number, status, total_amount, nursery_name,        │
// │                created_at, item_count                                        │
// │                                                                             │
// │  ✅  View order detail (with items + status history)                        │
// │        GET  /api/v1/orders/:id                                              │
// │        Fields: + items[{ plant_name, quantity, loaded_quantity, unit_price }]│
// │                  dispatches[{ dispatch_number, status, vehicle_number }]    │
// │                                                                             │
// │  ✅  Cancel own PENDING order                                               │
// │        POST /api/v1/orders/:id/cancel                                       │
// │        Guard: order.status MUST be PENDING — API returns 409 otherwise      │
// │        Side-effect: order.status → CANCELLED                                │
// │                                                                             │
// │  ✅  View dispatches for own orders                                         │
// │        GET  /api/v1/dispatches                                              │
// │        Query params: page, per_page                                         │
// │        Fields: id, dispatch_number, status, vehicle_number, driver_name,    │
// │                estimated_arrival, order_id, order_number                    │
// │                                                                             │
// │  ✅  Live dispatch tracking                                                 │
// │        GET  /api/v1/dispatches/:id/track                                    │
// │        Response: { latitude, longitude, last_updated, estimated_arrival,    │
// │                    status, waypoints[] }                                     │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — FORBIDDEN ACTIONS (must not appear in UI)                           │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Create orders          POST /api/v1/orders                             │
// │  ❌  Create quotations      POST /api/v1/quotations                         │
// │  ❌  Approve quotations     POST /api/v1/quotations/:id/approve             │
// │  ❌  Convert quotation to order  POST /api/v1/quotations/:id/convert-to-order│
// │  ❌  Delete quotations      DELETE /api/v1/quotations/:id                   │
// │  ❌  Modify orders          PUT  /api/v1/orders/:id                         │
// │  ❌  Add/remove order items POST /api/v1/orders/:id/items                   │
// │  ❌  Create dispatches      POST /api/v1/dispatches                         │
// │  ❌  Any inventory access   ANY  /api/v1/nurseries/:id/inventory            │
// │  ❌  Any sourcing access    ANY  /api/v1/sourcing                           │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// ORDER STATUS MACHINE (API-enforced, replicate in UI guards)
// ────────────────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED           → COMPLETED
//                                 → PARTIALLY_FULFILLED → COMPLETED
//   PENDING → CANCELLED   ← buyer can cancel ONLY from this state
//
// QUOTATION STATUS MACHINE
// ─────────────────────────
//   DRAFT → APPROVED → SENT | CUSTOMER_SENT
//                            → CUSTOMER_ACCEPTED  ← buyer action (buyer-accept)
//                            → CUSTOMER_REJECTED  ← buyer action (buyer-reject)
//                            → CONVERTED          ← nursery converts to order
//                            → EXPIRED            ← time-based
//
// PAGINATION PATTERN
// ───────────────────
//   All list endpoints return: { data: T[], pagination: { page, per_page, total, total_pages } }
//   Use ApiPagination from lib/core/models/pagination.dart
//   Implement pull-to-refresh (page=1) + infinite scroll (loadMore increments page)
//
// ERROR HANDLING
// ───────────────
//   403 forbidden        — user tried to access another buyer's order (should not happen if filtering by session)
//   404 not_found        — quotation/order no longer exists
//   409 conflict         — tried to cancel a non-PENDING order; tried to accept an expired quotation
//   422 unprocessable    — invalid page/per_page params
//
// NAVIGATION FROM THIS TAB
// ─────────────────────────
//   context.push('/quotations/:id')        — quotation detail sheet
//   context.push('/orders/:id')            — order detail page
//   context.push('/dispatches/:id/track')  — live tracking map
//
// SEE ALSO
// ─────────
//   lib/features/buyer/buyer_home.dart     — home section summary cards
//   lib/features/buyer/buyer_payments_screen.dart  — payment history
//   lib/features/buying/buying_screen.dart — role wrapper that routes here

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Buyer Buying tab — transaction hub for BUYER role users.
///
/// Empty placeholder — implement using the RBAC and API spec in the file header.
/// Tabs to build: Offers (quotations) | Orders | Deliveries (dispatches).
class BuyerTab extends StatelessWidget {
  const BuyerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Text('Buyer — Buying Tab', style: AppTypography.h3)),
    );
  }
}
