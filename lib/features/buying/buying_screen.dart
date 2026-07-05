// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — BUYING SCREEN  (Role-aware "Buying" tab wrapper)               ║
// ║  Route: second tab in MainShell for all non-driver roles                    ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// PURPOSE
// ───────
// BuyingScreen is a thin role dispatcher — it reads session capabilities and
// renders the correct role-specific tab content. It does NOT contain any UI of
// its own. The same tab slot in MainShell shows different content per role.
//
// ROLE DISPATCH LOGIC
// ────────────────────
//   caps.isNurseryOwner == true  →  OwnerTab
//       Owner's "Buying" view — owners can also browse and purchase as buyers.
//       OwnerTab is reused here (same full operations tab).
//
//   caps.isManager == true       →  ManagerWorkTab
//       Manager's work hub shown in the "Buying" tab slot.
//       Tab label in MainShell is "Work" for managers.
//       Managers do not have a separate buyer persona.
//
//   (default — pure buyer)       →  BuyerTab
//       Not an owner, not a manager, not a driver.
//       Buyer-only actions: view quotations (accept/reject), view orders, track dispatches.
//       CANNOT create orders or quotations.
//
// DRIVER EXCLUSION
// ─────────────────
//   Driver-only users (caps.isDriverOnly == true) NEVER see this tab.
//   MainShell._buildTabs() omits the Buying tab entirely for drivers.
//   This wrapper is never instantiated for isDriverOnly users.
//
// CAPABILITIES (from session_provider.dart → UserCapabilities)
// ─────────────────────────────────────────────────────────────
//   caps.isNurseryOwner   bool  — true if user owns a nursery
//   caps.isManager        bool  — true if user is a nursery manager
//   caps.isDriverOnly     bool  — true if user has ONLY a driver profile
//   caps.canSell          bool  — true if isNurseryOwner OR isManager
//   caps.primaryNurseryId int?  — nursery ID for all nursery-scoped API calls
//
// ROUTE GUARDS (router.dart)
// ───────────────────────────
//   Routes navigated to FROM this tab carry their own guards:
//     _buyerGuard      — blocks drivers and sellers from buyer-only routes (e.g. /my-payments)
//     _canSellGuard    — blocks buyers and drivers from seller-create routes
//     _ownerGuard      — blocks non-owners from owner-only routes (/nursery/members, /inventory/add)
//
// SEE ALSO
// ─────────
//   lib/features/buyer/buyer_tab.dart          — buyer-only tab (quotations + orders)
//   lib/features/owner/owner_tab.dart           — owner full operations tab
//   lib/features/manager/manager_work_tab.dart  — manager operations tab
//   lib/app/main_shell.dart                     — tab routing shell + driver exclusion
//   lib/features/selling/selling_screen.dart    — "Selling/Work" tab wrapper

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../buyer/buyer_tab.dart';
import '../manager/manager_work_tab.dart';

/// Role-aware "Buying" tab wrapper.
///
/// Owners buy from other nurseries as customers — identical buyer experience.
/// Managers do not have a buyer persona; they use the work tab.
class BuyingScreen extends ConsumerWidget {
  const BuyingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (caps.isManager) return const ManagerWorkTab();
    return const BuyerTab();
  }
}
