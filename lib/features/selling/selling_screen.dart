// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — SELLING SCREEN  (Role-aware "Selling / Work" tab wrapper)      ║
// ║  Route: shown as "Selling" tab (owner) or "Work" tab (manager) in MainShell ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// PURPOSE
// ───────
// SellingScreen is a thin role dispatcher for the second selling/work tab.
// It reads session capabilities and renders the correct role-specific content.
// The tab label and icon shown in MainShell differ by role (see main_shell.dart).
//
// ROLE DISPATCH LOGIC
// ────────────────────
//   caps.isManager == true        →  ManagerWorkTab
//       Managers see "Work" tab label with a work/tools icon.
//       Actions: orders, quotations, loading workflow, dispatch creation.
//       Managers checked FIRST because a manager is never also an owner.
//
//   caps.isNurseryOwner == true   →  OwnerTab
//       Owners see "Selling" tab label with a storefront icon.
//       Full operations: orders, quotations, inventory, team, sourcing, dispatch.
//
// BUYER AND DRIVER EXCLUSION
// ───────────────────────────
//   Buyers (no canSell capability) and drivers (isDriverOnly) NEVER see this tab.
//   MainShell._buildTabs() only adds this tab when caps.canSell == true.
//   (canSell = isNurseryOwner || isManager)
//   This wrapper is never instantiated for buyers or drivers.
//
// CAPABILITIES (from session_provider.dart → UserCapabilities)
// ─────────────────────────────────────────────────────────────
//   caps.isNurseryOwner   bool — true if user owns a nursery
//   caps.isManager        bool — true if user is a nursery manager (mutually exclusive with owner)
//   caps.canSell          bool — true if isNurseryOwner OR isManager
//   caps.primaryNurseryId int? — nursery ID for all nursery-scoped API calls
//
// CRITICAL BUSINESS RULE — MANAGER ≠ OWNER (mutually exclusive)
// ───────────────────────────────────────────────────────────────
//   A user CANNOT be both a manager and a nursery owner.
//   API enforces this with 409 conflicting_role on nursery registration for managers.
//   Therefore isManager and isNurseryOwner are never both true at the same time.
//   The isManager check before isNurseryOwner is safe — but both paths produce
//   different screens anyway.
//
// ROUTE GUARDS (router.dart)
// ───────────────────────────
//   Routes navigated to from this tab:
//     _canSellGuard    — blocks buyers/drivers from seller-create routes
//     _ownerGuard      — blocks managers (and all non-owners) from owner-only routes
//                         e.g. /nursery/members, /inventory/add
//   This wrapper itself has no route guard — canSell users always have this tab.
//
// SEE ALSO
// ─────────
//   lib/features/owner/owner_tab.dart           — owner selling tab implementation
//   lib/features/manager/manager_work_tab.dart  — manager work tab implementation
//   lib/app/main_shell.dart                     — tab routing shell
//   lib/features/buying/buying_screen.dart      — "Buying" tab wrapper

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../manager/manager_work_tab.dart';
import '../owner/owner_tab.dart';

/// Role-aware "Selling / Work" tab wrapper.
///
/// Manager → ManagerWorkTab. Owner → OwnerTab (quotations, orders, dispatches).
class SellingScreen extends ConsumerWidget {
  const SellingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (caps.isManager) return const ManagerWorkTab();
    return const OwnerTab();
  }
}
