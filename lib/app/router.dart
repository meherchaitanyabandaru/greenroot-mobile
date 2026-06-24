import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/create_profile_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/role_select_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/domain/rbac/roles.dart';
import '../features/dashboard/admin/admin_dashboard.dart';
import '../features/dashboard/buyer/buyer_dashboard.dart';
import '../features/dashboard/driver/driver_dashboard.dart';
import '../features/dashboard/manager/manager_dashboard.dart';
import '../features/dashboard/owner/owner_dashboard.dart';
import '../features/dashboard/transport/transport_dashboard.dart';
import '../features/notifications/notification_list_screen.dart';
import '../features/plants/plant_detail_screen.dart';
import '../features/nurseries/nursery_detail_screen.dart';
import '../features/inventory/inventory_detail_screen.dart';
import '../features/inventory/inventory_add_screen.dart';
import '../features/requests/request_detail_screen.dart';
import '../features/requests/request_create_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_create_screen.dart';
import '../features/dispatches/dispatch_detail_screen.dart';
import '../features/dispatches/dispatch_list_screen.dart';

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
        path: '/create-profile', builder: (_, __) => const CreateProfileScreen()),
    GoRoute(path: '/role-select', builder: (_, __) => const RoleSelectScreen()),

    // ── Role dashboards ──────────────────────────────────────────────────────
    GoRoute(path: '/home/buyer', builder: (_, __) => const BuyerDashboard()),
    GoRoute(
        path: '/home/nursery-owner', builder: (_, __) => const OwnerDashboard()),
    GoRoute(path: '/home/owner', builder: (_, __) => const OwnerDashboard()),
    GoRoute(path: '/home/manager', builder: (_, __) => const ManagerDashboard()),
    GoRoute(path: '/home/driver', builder: (_, __) => const DriverDashboard()),
    GoRoute(
        path: '/home/transport-provider',
        builder: (_, __) => const TransportDashboard()),
    GoRoute(
        path: '/home/transport', builder: (_, __) => const TransportDashboard()),
    GoRoute(
        path: '/home/admin',
        builder: (_, __) => const AdminDashboard(role: AppRole.admin)),
    GoRoute(
        path: '/home/super-admin',
        builder: (_, __) => const AdminDashboard(role: AppRole.superAdmin)),

    // ── Notifications ────────────────────────────────────────────────────────
    GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationListScreen()),

    // ── Plants ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/plants/:id',
      builder: (_, state) =>
          PlantDetailScreen(plantId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Nurseries ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/nurseries/:id',
      builder: (_, state) => NurseryDetailScreen(
          nurseryId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Inventory ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/inventory/add',
      builder: (_, __) => const InventoryAddScreen(),
    ),
    GoRoute(
      path: '/inventory/:id',
      builder: (_, state) => InventoryDetailScreen(
          itemId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Requests ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/requests/create',
      builder: (_, __) => const RequestCreateScreen(),
    ),
    GoRoute(
      path: '/requests/:id',
      builder: (_, state) => RequestDetailScreen(
          requestId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Orders ────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/orders/create',
      builder: (_, __) => const OrderCreateScreen(),
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (_, state) =>
          OrderDetailScreen(orderId: int.parse(state.pathParameters['id']!)),
    ),

    // ── Dispatches ────────────────────────────────────────────────────────────
    GoRoute(
      path: '/dispatches',
      builder: (_, __) => const DispatchListScreen(),
    ),
    GoRoute(
      path: '/dispatches/:id',
      builder: (_, state) => DispatchDetailScreen(
          dispatchId: int.parse(state.pathParameters['id']!)),
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
