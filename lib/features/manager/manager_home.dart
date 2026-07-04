// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — MANAGER HOME SECTION                                            ║
// ║  Role:  MANAGER (Gumastha)                                                   ║
// ║  Guard: rendered only when caps.isManager == true                            ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// CONTEXT
// ───────
// Rendered inside HomeScreen as the main content block for a MANAGER (Gumastha).
// The manager is a nursery employee assigned by a nursery owner. They have
// operational access to the nursery without ownership rights.
//
// Dispatch condition in home_screen.dart:
//   else if (caps.isManager) ManagerHome()
//
// CRITICAL BUSINESS RULE — MANAGER ≠ OWNER
// ─────────────────────────────────────────
//   A manager CANNOT be a nursery owner simultaneously.
//   If a user is already a manager and tries to register a nursery:
//     API returns 409 conflicting_role
//   This means caps.isManager and caps.isNurseryOwner are mutually exclusive.
//   Never show the "Register Nursery" CTA for managers.
//
// NURSERY CONTEXT
// ────────────────
// Manager is linked to a nursery through their membership:
//   caps.primaryNurseryId  — the nursery they manage (from session)
//   All nursery-scoped API calls use this ID
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — WHAT A MANAGER CAN DO (home dashboard context)                     │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  View assigned nursery orders      GET  /api/v1/orders                  │
// │  ✅  View order detail                 GET  /api/v1/orders/:id              │
// │  ✅  Create orders for buyers          POST /api/v1/orders                  │
// │  ✅  Confirm order                     POST /api/v1/orders/:id/confirm       │
// │  ✅  Cancel order (PENDING/CONFIRMED)  POST /api/v1/orders/:id/cancel        │
// │  ✅  Start loading (CONFIRMED→LOADING) POST /api/v1/orders/:id/start-loading │
// │  ✅  Set loaded quantity per item      PUT  /api/v1/orders/:id/items/:itemId/loaded-quantity│
// │  ✅  Complete loading (→LOADED)        POST /api/v1/orders/:id/complete-loading│
// │  ✅  Create quotations for buyers      POST /api/v1/quotations               │
// │  ✅  View quotations                   GET  /api/v1/quotations               │
// │  ✅  Approve quotation                 POST /api/v1/quotations/:id/approve   │
// │  ✅  Convert accepted quotation→order  POST /api/v1/quotations/:id/convert-to-order│
// │  ✅  View inventory (read-only)        GET  /api/v1/nurseries/:id/inventory  │
// │  ✅  Create dispatches                 POST /api/v1/dispatches               │
// │  ✅  View dispatches                   GET  /api/v1/dispatches               │
// │  ✅  Invite customers                  POST /api/v1/invites  (CUSTOMER_INVITE)│
// │  ✅  Invite drivers (if applicable)    POST /api/v1/invites  (DRIVER_INVITE) │
// │  ✅  Browse sourcing network           GET  /api/v1/sourcing                 │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — WHAT A MANAGER CANNOT DO                                            │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Invite managers  POST /api/v1/invites (MANAGER_INVITE) — owner only    │
// │  ❌  View team list   GET /api/v1/nurseries/:id/managers     — owner only   │
// │  ❌  Delete orders    DELETE /api/v1/orders/:id               — owner only  │
// │  ❌  Delete quotations DELETE /api/v1/quotations/:id          — owner only  │
// │  ❌  Modify inventory  POST/PUT/DELETE /api/v1/inventory       — owner only │
// │  ❌  Update nursery settings PUT /api/v1/nurseries/:id         — owner only │
// │  ❌  Register nursery POST /api/v1/nurseries  (409 conflicting_role)        │
// │  ❌  Access /nursery/members route (blocked by _ownerGuard in router.dart)  │
// │  ❌  Access /inventory/add route (blocked by _ownerGuard in router.dart)    │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// API CALLS — ON LOAD & PULL-TO-REFRESH
// ──────────────────────────────────────
//   1. GET /api/v1/orders?page=1&per_page=10&status=PENDING,CONFIRMED,LOADING
//        → Work queue: orders awaiting confirmation, loading
//
//   2. GET /api/v1/orders?page=1&per_page=5&status=LOADING
//        → Active loading sessions — loading progress cards
//
//   3. GET /api/v1/quotations?page=1&per_page=5&status=DRAFT,CUSTOMER_ACCEPTED
//        → Quotations needing action: unsent drafts + accepted ones to convert
//
//   4. GET /api/v1/dispatches?page=1&per_page=5
//        → Outbound dispatches overview
//
// ORDER STATUS MACHINE (same as owner — API-enforced)
// ──────────────────────────────────────────────────────
//   PENDING → CONFIRMED → LOADING → LOADED | PARTIALLY_FULFILLED → COMPLETED
//   PENDING or CONFIRMED → CANCELLED
//   Manager CAN cancel from PENDING or CONFIRMED, same as owner
//   Manager CANNOT delete orders at any stage
//
// NAVIGATION FROM THIS WIDGET
// ────────────────────────────
//   context.push('/orders/:id')          — order detail + state-machine actions
//   context.push('/orders/:id/loading')  — loading workflow screen
//   context.push('/quotations/:id')      — quotation detail + approve/convert
//   context.push('/dispatches/:id')      — dispatch creation/assignment
//   context.push('/plants')              — browse plants (for quotation item lookup)
//
// BUSINESS RULES — MUST ENFORCE IN UI
// ─────────────────────────────────────
//   • Never show "Register Nursery" CTA — will always fail with 409 conflicting_role
//   • Never show "Invite Manager" option — MANAGER_INVITE is owner-only
//   • Never show "Delete Order" button — not permitted
//   • Never navigate to /nursery/members — _ownerGuard redirects to /home
//   • Show inventory in READ-ONLY mode (no add/edit/delete controls)
//   • Loading queue is the primary manager home card (loading is the core work)
//
// SEE ALSO
// ─────────
//   lib/features/manager/manager_work_tab.dart  — full work tab content
//   lib/features/buying/buying_screen.dart       — routes to ManagerWorkTab
//   lib/features/selling/selling_screen.dart     — routes to ManagerWorkTab

import 'package:flutter/material.dart';

/// Manager home section rendered inside HomeScreen for managers (Gumastha).
///
/// Empty placeholder — implement using the RBAC and API spec in the file header.
/// Build: work queue (orders needing action), active loading sessions,
/// quotations to action, dispatch overview. NO inventory management, NO team management.
class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
