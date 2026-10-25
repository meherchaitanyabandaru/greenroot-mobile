// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  GREENROOT — OWNER MEMBERS SCREEN  (Team + Customer Management)             ║
// ║  Role:   NURSERY_OWNER only                                                  ║
// ║  Route:  /nursery/members                                                    ║
// ║  Guard:  _ownerGuard — blocks managers, buyers, and drivers                 ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// PURPOSE
// ───────
// Team and customer management screen for nursery owners. Provides two tabs:
//   Tab 1: "Managers" — list of managers assigned to the nursery + invite more
//   Tab 2: "Customers" — list of customer invites + invite new customers
//
// NURSERY CONTEXT
// ────────────────
//   All API calls are scoped to caps.primaryNurseryId (the owner's nursery).
//   Loaded from session: ref.watch(sessionProvider).capabilities.primaryNurseryId
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  RBAC — ALLOWED ACTIONS (OWNER ONLY)                                        │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ✅  List nursery managers             GET  /api/v1/nurseries/:id/managers  │
// │        Response: { data: [NurseryManager...] }                              │
// │        Fields: id, user_id, name, mobile, email, role                       │
// │                                                                             │
// │  ✅  List nursery invites              GET  /api/v1/nurseries/:id/invites   │
// │        Query params: page, per_page                                         │
// │        Response: { data: [NurseryInvite...], pagination: {...} }            │
// │        Fields: id, uuid, invite_type, status, target_name,                  │
// │                target_mobile, target_email, created_at                       │
// │        invite_type values: MANAGER_INVITE | CUSTOMER_INVITE                 │
// │        status values: PENDING | ACCEPTED | EXPIRED | REVOKED                │
// │                                                                             │
// │  ✅  Create MANAGER_INVITE             POST /api/v1/invites                 │
// │        Body: { nursery_id, invite_type: "MANAGER_INVITE",                   │
// │               mobile?: string, email?: string, name?: string }              │
// │        Response: invite object with uuid (used to generate QR/deep-link)    │
// │        Side-effect: invited user becomes a MANAGER on accepting              │
// │        Business rule: invited user CANNOT already be a nursery owner        │
// │                                                                             │
// │  ✅  Create CUSTOMER_INVITE            POST /api/v1/invites                 │
// │        Body: { nursery_id, invite_type: "CUSTOMER_INVITE",                  │
// │               mobile?: string, email?: string, name?: string }              │
// │        Response: invite object with uuid                                     │
// │        Side-effect: invited user becomes a registered customer of nursery   │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  RBAC — FORBIDDEN                                                           │
// ├─────────────────────────────────────────────────────────────────────────────┤
// │  ❌  Managers cannot access this screen (_ownerGuard → /home)               │
// │  ❌  Managers cannot create MANAGER_INVITE (only owner can invite managers) │
// │  ❌  Remove/revoke manager — not yet implemented in API v1                  │
// │  ❌  Access other nurseries' teams — API scoped to own nursery only         │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// INVITE FLOW
// ────────────
//   1. Owner creates invite → POST /api/v1/invites
//   2. API returns invite.uuid
//   3. App generates deep-link: greenroot://invite/:uuid  OR QR code
//   4. Owner shares link/QR with target person (via WhatsApp, etc.)
//   5. Target person taps link → app opens InviteAcceptScreen (/invite/:uuid)
//   6. Target accepts → POST /api/v1/invites/:uuid/accept
//   7. For MANAGER_INVITE: target gains manager role for the nursery
//   8. For CUSTOMER_INVITE: target is registered as a customer of the nursery
//
// INVITE STATUS VALUES
// ─────────────────────
//   PENDING   — invite created, not yet accepted
//   ACCEPTED  — invite was accepted; recipient has the role
//   EXPIRED   — invite validity window passed (API-controlled TTL)
//   REVOKED   — owner revoked the invite before acceptance
//
// ERROR HANDLING
// ───────────────
//   409 conflicting_role — invited user is already a nursery owner (for MANAGER_INVITE)
//   404 not_found        — nursery not found (should not happen with valid primaryNurseryId)
//   422 unprocessable    — neither mobile nor email provided in invite body
//
// SEE ALSO
// ─────────
//   lib/features/owner/owner_tab.dart        — routing entry point
//   lib/features/owner/owner_home.dart       — home dashboard
//   lib/app/router.dart _ownerGuard          — route guard blocking non-owners
//   lib/features/invites/invite_accept_screen.dart — the invite acceptance flow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/testing/test_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/qr_share_sheet.dart';

part 'owner_members_invite.dart';
part 'owner_members_tabs.dart';
part 'owner_members_state.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class MembersScreen extends ConsumerStatefulWidget {
  final int nurseryId;
  final String nurseryName;
  final int initialTab; // 0 = Managers, 1 = Drivers, 2 = Customers

  const MembersScreen({
    super.key,
    required this.nurseryId,
    required this.nurseryName,
    this.initialTab = 0,
  });

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(membersProvider(widget.nurseryId).notifier).load(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(membersProvider(widget.nurseryId));

    return Scaffold(
      key: const Key(TestKeys.membersScreen),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My People', style: AppTypography.h3),
            Text(
              widget.nurseryName,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(membersProvider(widget.nurseryId).notifier).load(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          labelStyle: AppTypography.label,
          unselectedLabelStyle: AppTypography.bodySmall,
          tabs: const [
            Tab(key: Key(TestKeys.membersManagersTab), text: 'Managers'),
            Tab(key: Key(TestKeys.membersDriversTab), text: 'Drivers'),
            Tab(
                key: Key(TestKeys.membersCustomersTab),
                text: 'Customers (Party)',),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMain),
            )
          : state.error != null &&
                  state.managers.isEmpty &&
                  state.invites.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () => ref
                      .read(membersProvider(widget.nurseryId).notifier)
                      .load(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _ManagersTab(
                      nurseryId: widget.nurseryId,
                      nurseryName: widget.nurseryName,
                      managers: state.managers,
                      // Accepted ones are already under Active Managers.
                      invites: state.invites
                          .where(
                            (i) =>
                                i.inviteType == 'MANAGER_INVITE' &&
                                i.isPending,
                          )
                          .toList(),
                    ),
                    _DriversTab(
                      nurseryId: widget.nurseryId,
                      nurseryName: widget.nurseryName,
                      drivers: state.drivers,
                    ),
                    _CustomersTab(
                      nurseryId: widget.nurseryId,
                      nurseryName: widget.nurseryName,
                      customers: state.customers,
                      pendingInvites: state.invites
                          .where(
                            (i) =>
                                i.inviteType == 'CUSTOMER_INVITE' &&
                                i.isPending,
                          )
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}

// ── Managers Tab ──────────────────────────────────────────────────────────────
