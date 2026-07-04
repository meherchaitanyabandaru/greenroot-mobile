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

String? _canSellGuard(BuildContext context, GoRouterState state) {
  final driverRedirect = _driverGuard(context, state);
  if (driverRedirect != null) return driverRedirect;
  return _capabilities(context).canSell ? null : '/home';
}

String? _ownerGuard(BuildContext context, GoRouterState state) {
  final driverRedirect = _driverGuard(context, state);
  if (driverRedirect != null) return driverRedirect;
  return _capabilities(context).isNurseryOwner ? null : '/home';
}

String? _sellerReadGuard(BuildContext context, GoRouterState state) {
  final driverRedirect = _driverGuard(context, state);
  if (driverRedirect != null) return driverRedirect;
  return _capabilities(context).canSell ? null : '/home';
}

// Buyer-only routes: blocks drivers AND sellers (owner/manager) from buyer-specific screens.
// Buyers are users who are not owners, not managers, and not driver-only.
String? _buyerGuard(BuildContext context, GoRouterState state) {
  final caps = _capabilities(context);
  if (caps.isDriverOnly) return '/home';
  if (caps.canSell) return '/home'; // owner or manager → not a buyer-only screen
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
