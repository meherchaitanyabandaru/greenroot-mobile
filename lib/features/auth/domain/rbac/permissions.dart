import 'roles.dart';

enum AppPermission {
  // Plants
  plantsRead('plants.read'),

  // Nurseries
  nurseriesRead('nurseries.read'),
  nurseriesWrite('nurseries.write'),

  // Inventory
  inventoryRead('inventory.read'),
  inventoryWrite('inventory.write'),

  // Plant sourcing network
  sourcingRead('sourcing.read'),
  sourcingWrite('sourcing.write'),

  // Requests
  requestCreate('request.create'),
  requestRead('request.read'),
  requestRespond('request.respond'),

  // Orders
  ordersRead('orders.read'),
  ordersCreate('orders.create'),

  // Payments
  paymentsRead('payments.read'),

  // Dispatches
  dispatchRead('dispatch.read'),
  dispatchStart('dispatch.start'),
  dispatchComplete('dispatch.complete'),

  // Tracking
  trackingRead('tracking.read'),
  trackingUpdate('tracking.update'),

  // Notifications
  notificationsRead('notifications.read'),

  // Profile
  profileRead('profile.read'),
  profileWrite('profile.write');

  final String value;
  const AppPermission(this.value);
}

/// Static role → permissions mapping.
/// Mirrors the backend RBAC policy without calling the API.
const Map<AppRole, Set<AppPermission>> rolePermissions = {
  AppRole.buyer: {
    AppPermission.plantsRead,
    AppPermission.nurseriesRead,
    AppPermission.ordersRead,
    AppPermission.ordersCreate,
    AppPermission.paymentsRead,
    AppPermission.trackingRead,
    AppPermission.notificationsRead,
    AppPermission.profileRead,
    AppPermission.profileWrite,
  },
  AppRole.nurseryOwner: {
    AppPermission.plantsRead,
    AppPermission.nurseriesRead,
    AppPermission.nurseriesWrite,
    AppPermission.inventoryRead,
    AppPermission.inventoryWrite,
    AppPermission.requestCreate,
    AppPermission.requestRead,
    AppPermission.requestRespond,
    AppPermission.ordersRead,
    AppPermission.ordersCreate,
    AppPermission.paymentsRead,
    AppPermission.dispatchRead,
    AppPermission.trackingRead,
    AppPermission.sourcingRead,
    AppPermission.sourcingWrite,
    AppPermission.notificationsRead,
    AppPermission.profileRead,
    AppPermission.profileWrite,
  },
  AppRole.manager: {
    AppPermission.plantsRead,
    AppPermission.nurseriesRead,
    AppPermission.inventoryRead,
    AppPermission.requestCreate,
    AppPermission.requestRead,
    AppPermission.requestRespond,
    AppPermission.ordersRead,
    AppPermission.ordersCreate,
    AppPermission.paymentsRead,
    AppPermission.dispatchRead,
    AppPermission.trackingRead,
    AppPermission.sourcingRead,
    AppPermission.sourcingWrite,
    AppPermission.notificationsRead,
    AppPermission.profileRead,
    AppPermission.profileWrite,
  },
  AppRole.driver: {
    AppPermission.dispatchRead,
    AppPermission.dispatchStart,
    AppPermission.dispatchComplete,
    AppPermission.trackingRead,
    AppPermission.trackingUpdate,
    AppPermission.notificationsRead,
    AppPermission.profileRead,
    AppPermission.profileWrite,
  },
};
