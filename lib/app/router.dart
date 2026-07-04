import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/data/models/capabilities_model.dart';
import '../features/auth/domain/rbac/roles.dart';
import '../features/auth/presentation/providers/session_provider.dart';
import '../features/auth/presentation/screens/create_profile_screen.dart';
import '../features/auth/presentation/screens/driver_registration_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/activity_select_screen.dart';
import '../features/auth/presentation/screens/nursery_pending_screen.dart';
import '../features/auth/presentation/screens/nursery_registration_screen.dart';
import '../features/auth/presentation/screens/nursery_rejected_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/workspace_select_screen.dart';
import '../features/dashboard/admin/admin_dashboard.dart';
import '../features/dispatches/dispatch_detail_screen.dart';
import '../features/dispatches/dispatch_list_screen.dart';
import '../features/driver/delivery_proof_screen.dart';
import '../features/driver/driver_scan_screen.dart';
import '../features/driver/driver_trips_screen.dart';
import '../features/driver/driver_trip_map_screen.dart';
import '../features/driver/trip_event_screen.dart';
import '../features/driver/trip_preview_screen.dart';
import '../features/inventory/inventory_add_screen.dart';
import '../features/inventory/inventory_detail_screen.dart';
import '../features/inventory/inventory_list_screen.dart';
import '../features/requests/request_list_screen.dart';
import '../features/invites/invite_accept_screen.dart';
import '../features/notifications/notification_list_screen.dart';
import '../features/nurseries/nursery_detail_screen.dart';
import '../features/nurseries/nursery_list_screen.dart';
import '../features/plants/plant_list_screen.dart';
import '../features/profile/my_addresses_screen.dart';
import '../features/buyer/buyer_payments_screen.dart';
import '../features/orders/order_create_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_loading_screen.dart';
import '../features/orders/order_list_screen.dart';
import '../features/plants/plant_detail_screen.dart';
import '../features/quotations/quotation_create_screen.dart';
import '../features/quotations/quotation_detail_screen.dart';
import '../features/quotations/quotation_list_screen.dart';
import '../features/quotations/quotations.dart';
import '../features/requests/request_create_screen.dart';
import '../features/owner/owner_members_screen.dart';
import '../features/requests/request_detail_screen.dart';
import '../features/connections/connections_screen.dart';
import '../features/sourcing/sourcing_screen.dart';
import '../features/tracking/dispatch_tracking_screen.dart';
import 'main_shell.dart';

UserCapabilities _capabilities(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(sessionProvider).capabilities;
}

// ============================================================================
// ROUTE GUARDS — RBAC at the navigation layer
// ============================================================================
//
// Guards run on every navigation event (initial load, push, deep-link redirect).
// Return null  → allow navigation.
// Return '/home' → block and redirect to home.
//
// GUARD MATRIX
// ─────────────────────────────────────────────────────────────
//   Guard              BUYER   OWNER   MANAGER   DRIVER-ONLY
//   _driverGuard        pass    pass    pass      block*
//   _canSellGuard       block   pass    pass      block
//   _sellerReadGuard    block   pass    pass      block
//   _ownerGuard         block   pass    block     block
//   _buyerGuard         pass    block   block     block
//
//   *driver pass: only /driver/*, /notifications, /dispatches/:id/track
//
// CAPABILITIES (UserCapabilities from session_provider.dart)
//   caps.isNurseryOwner  — user owns a nursery (mutually exclusive with isManager)
//   caps.isManager       — user is a nursery manager (mutually exclusive with isNurseryOwner)
//   caps.isDriverOnly    — user has ONLY a driver profile, no other role
//   caps.canSell         — isNurseryOwner || isManager  (shorthand for sell access)
//   caps.primaryNurseryId — nursery ID for all nursery-scoped API calls
//
// ============================================================================

// _driverGuard: confine driver-only users to driver screens.
// Non-drivers pass through immediately (null).
// Driver-allowed paths: /driver/*, /notifications, /dispatches/:id/track
// Everything else for a driver → /home
String? _driverGuard(BuildContext context, GoRouterState state) {
  final caps = _capabilities(context);
  if (!caps.isDriverOnly) return null;

  final path = state.uri.path;
  if (path.startsWith('/driver/')) return null;
  if (path == '/notifications' ||
      path.startsWith('/dispatches/') && path.endsWith('/track')) {
    return null;
  }
  return '/home';
}

// _canSellGuard: require canSell capability (owner OR manager).
// Blocks: pure buyers, driver-only users.
// Applied on: seller-create routes — order create, quotation create, dispatch create.
// API equivalent: routes that call POST /api/v1/orders, POST /api/v1/quotations, etc.
String? _canSellGuard(BuildContext context, GoRouterState state) {
  final driverRedirect = _driverGuard(context, state);
  if (driverRedirect != null) return driverRedirect;
  return _capabilities(context).canSell ? null : '/home';
}

// _ownerGuard: require isNurseryOwner (NOT just canSell).
// Blocks: managers (canSell=true but isNurseryOwner=false), buyers, drivers.
// Applied on: owner-exclusive routes:
//   /nursery/members    → team management, MANAGER_INVITE (owner-only API)
//   /inventory/add      → add inventory items (owner-only API)
// API equivalent: POST /api/v1/invites (MANAGER_INVITE), POST /api/v1/nurseries/:id/inventory
String? _ownerGuard(BuildContext context, GoRouterState state) {
  final driverRedirect = _driverGuard(context, state);
  if (driverRedirect != null) return driverRedirect;
  return _capabilities(context).isNurseryOwner ? null : '/home';
}

// _sellerReadGuard: require canSell for read-only seller views.
// Blocks: buyers (no canSell), drivers.
// Applied on: routes that display nursery-scope read data (order lists,
// dispatch lists, quotation lists) scoped to the seller's nursery context.
// Note: buyers have their own buyer-scoped versions of these lists.
String? _sellerReadGuard(BuildContext context, GoRouterState state) {
  final driverRedirect = _driverGuard(context, state);
  if (driverRedirect != null) return driverRedirect;
  return _capabilities(context).canSell ? null : '/home';
}

// _buyerGuard: restrict routes to pure buyer users only.
// A "pure buyer" is: !isDriverOnly && !canSell
// Blocks: owners (canSell=true), managers (canSell=true), driver-only users.
// Applied on: /my-payments (buyer payment history — GET /api/v1/payments scoped to buyer)
//
// IMPORTANT: owners and managers also use payments — but their payment routes
// are seller-scoped (order-linked). Use _canSellGuard for those routes, not this.
String? _buyerGuard(BuildContext context, GoRouterState state) {
  final caps = _capabilities(context);
  if (caps.isDriverOnly) return '/home';
  if (caps.canSell) return '/home'; // owner or manager → blocked from buyer-only screens
  return null;
}

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    // ── Splash ──────────────────────────────────────────────────────────────
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),

    // ── Auth ────────────────────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/otp',
      builder: (_, state) => OtpScreen(mobile: state.extra as String? ?? ''),
    ),
    GoRoute(
        path: '/create-profile',
        builder: (_, __) => const CreateProfileScreen()),

    // Workspace selector — still reachable from profile or direct nav
    GoRoute(
        path: '/workspace-select',
        builder: (_, __) => const WorkspaceSelectScreen()),
    GoRoute(path: '/role-select', redirect: (_, __) => '/workspace-select'),

    // ── Registration / Onboarding ────────────────────────────────────────────
    GoRoute(
        path: '/select-activity',
        builder: (_, __) => const ActivitySelectScreen()),
    GoRoute(
        path: '/register/driver',
        builder: (_, __) => const DriverRegistrationScreen()),
    GoRoute(
        path: '/register/nursery',
        builder: (_, __) => const NurseryRegistrationScreen()),

    // ── Nursery application status ───────────────────────────────────────────
    GoRoute(
        path: '/nursery/pending',
        builder: (_, __) => const NurseryPendingScreen()),
    GoRoute(
        path: '/nursery/rejected',
        builder: (_, __) => const NurseryRejectedScreen()),

    // ── Invite accept ────────────────────────────────────────────────────────
    GoRoute(
        path: '/invite/accept', builder: (_, __) => const InviteAcceptScreen()),
    GoRoute(
      path: '/invite/:uuid',
      builder: (_, state) =>
          InviteAcceptScreen(preloadedUUID: state.pathParameters['uuid']),
    ),

    // ── Unified home shell (Phase 4) ─────────────────────────────────────────
    GoRoute(path: '/home', builder: (_, __) => const MainShell()),

    // Legacy role-specific routes — redirect to unified home
    GoRoute(path: '/home/buyer', redirect: (_, __) => '/home'),
    GoRoute(path: '/home/nursery-owner', redirect: (_, __) => '/home'),
    GoRoute(path: '/home/owner', redirect: (_, __) => '/home'),
    GoRoute(path: '/home/manager', redirect: (_, __) => '/home'),
    GoRoute(path: '/home/driver', redirect: (_, __) => '/home'),

    // Admin dashboard stays separate
    GoRoute(
        path: '/home/admin',
        builder: (_, __) => const AdminDashboard(role: AppRole.admin)),

    // ── Notifications ────────────────────────────────────────────────────────
    GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationListScreen()),

    // ── Driver-only routes ────────────────────────────────────────────────────
    GoRoute(
      path: '/driver/scan',
      builder: (_, __) => const DriverScanScreen(),
    ),
    GoRoute(
      path: '/driver/scan/preview',
      builder: (_, state) =>
          TripPreviewScreen(code: state.uri.queryParameters['code'] ?? ''),
    ),
    GoRoute(
      path: '/driver/trips',
      builder: (_, __) => const DriverTripsScreen(),
    ),
    GoRoute(
      path: '/driver/trip/:id',
      builder: (_, state) => DriverTripMapScreen(
          dispatchId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/driver/trips/:id/event',
      builder: (_, state) =>
          TripEventScreen(dispatchId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/driver/trips/:id/proof',
      builder: (_, state) => DeliveryProofScreen(
          dispatchId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Plants ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/plants',
      redirect: _driverGuard,
      builder: (_, __) => const PlantListScreen(),
    ),
    GoRoute(
      path: '/plants/:id',
      redirect: _driverGuard,
      builder: (_, state) =>
          PlantDetailScreen(plantId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Nurseries ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/nurseries',
      redirect: _driverGuard,
      builder: (_, __) => const NurseryListScreen(),
    ),
    GoRoute(
      path: '/nurseries/:id',
      builder: (_, state) => NurseryDetailScreen(
          nurseryId: int.parse(state.pathParameters['id']!)),
    ),

    // ── My Profile sub-screens ────────────────────────────────────────────────
    GoRoute(
      path: '/my-addresses',
      redirect: _driverGuard,
      builder: (_, __) => const MyAddressesScreen(),
    ),
    GoRoute(
      path: '/my-payments',
      redirect: _buyerGuard,
      builder: (_, __) => const BuyerPaymentsScreen(),
    ),

    // ── Inventory ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/inventory',
      redirect: _canSellGuard,
      builder: (_, __) => const InventoryListScreen(),
    ),
    GoRoute(
      path: '/inventory/add',
      redirect: _ownerGuard,
      builder: (_, __) => const InventoryAddScreen(),
    ),
    GoRoute(
      path: '/inventory/:id',
      redirect: _canSellGuard,
      builder: (_, state) =>
          InventoryDetailScreen(itemId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Requests ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/requests',
      redirect: _canSellGuard,
      builder: (_, __) => const RequestListScreen(),
    ),
    GoRoute(
      path: '/requests/create',
      redirect: _canSellGuard,
      builder: (_, __) => const RequestCreateScreen(),
    ),
    GoRoute(
      path: '/requests/:id',
      redirect: _canSellGuard,
      builder: (_, state) => RequestDetailScreen(
          requestId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Orders ────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/orders',
      redirect: _driverGuard,
      builder: (_, state) {
        final nurseryId =
            int.tryParse(state.uri.queryParameters['nursery'] ?? '');
        final status = state.uri.queryParameters['status'];
        return OrderListScreen(nurseryId: nurseryId, statusFilter: status);
      },
    ),
    GoRoute(
      path: '/orders/loading',
      redirect: _canSellGuard,
      builder: (_, state) {
        final nurseryId =
            int.tryParse(state.uri.queryParameters['nursery'] ?? '');
        return OrderLoadingScreen(nurseryId: nurseryId);
      },
    ),
    GoRoute(
      path: '/orders/create',
      redirect: _canSellGuard,
      builder: (_, __) => const OrderCreateScreen(),
    ),
    GoRoute(
      path: '/orders/:id',
      redirect: _driverGuard,
      builder: (_, state) =>
          OrderDetailScreen(orderId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Quotations ────────────────────────────────────────────────────────────
    GoRoute(
      path: '/quotations',
      redirect: _driverGuard,
      builder: (_, __) => const QuotationListScreen(),
    ),
    GoRoute(
      path: '/quotations/create',
      redirect: _canSellGuard,
      builder: (_, state) {
        final type = state.uri.queryParameters['type'];
        return QuotationCreateScreen(initialType: type);
      },
    ),
    GoRoute(
      path: '/quotations/:id',
      redirect: _driverGuard,
      builder: (_, state) => QuotationDetailScreen(
          quotationId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/quotations/:id/edit',
      redirect: _canSellGuard,
      builder: (_, state) =>
          QuotationCreateScreen(quotation: state.extra as Quotation?),
    ),

    // ── Connections ───────────────────────────────────────────────────────────
    GoRoute(
      path: '/connections',
      redirect: _canSellGuard,
      builder: (_, __) => const ConnectionsScreen(),
    ),

    // ── Plant Sourcing Network ───────────────────────────────────────────────
    GoRoute(
      path: '/sourcing',
      redirect: _canSellGuard,
      builder: (_, __) => const SourcingScreen(),
    ),

    // ── Nursery Members Management ────────────────────────────────────────────
    GoRoute(
      path: '/nursery/members',
      redirect: _ownerGuard,
      builder: (_, state) {
        final id = int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0;
        final name = state.uri.queryParameters['name'] ?? 'My Nursery';
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
        return MembersScreen(
          nurseryId: id,
          nurseryName: name,
          initialTab: tab,
        );
      },
    ),

    // ── Dispatches ────────────────────────────────────────────────────────────
    GoRoute(
      path: '/dispatches',
      redirect: _sellerReadGuard,
      builder: (_, __) => const DispatchListScreen(),
    ),
    GoRoute(
      path: '/dispatches/:id',
      redirect: _sellerReadGuard,
      builder: (_, state) => DispatchDetailScreen(
          dispatchId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/dispatches/:id/track',
      builder: (_, state) => DispatchTrackingScreen(
        dispatchId: int.parse(state.pathParameters['id']!),
        title: state.uri.queryParameters['title'],
        isDriver: state.uri.queryParameters['driver'] == 'true',
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  ),
);
