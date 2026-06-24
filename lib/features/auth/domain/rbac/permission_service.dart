import 'permissions.dart';
import 'roles.dart';

class PermissionService {
  final List<AppRole> _roles;
  final AppRole? _activeRole;

  const PermissionService({
    required List<AppRole> roles,
    AppRole? activeRole,
  })  : _roles = roles,
        _activeRole = activeRole;

  // ── Role checks ────────────────────────────────────────────────────────────
  bool hasRole(AppRole role) => _roles.contains(role);
  bool hasAnyRole(List<AppRole> roles) => roles.any(_roles.contains);

  bool get isMultiRole => _roles.where((r) => r.isMobileRole).length > 1;
  bool get isAdmin => hasRole(AppRole.admin) || hasRole(AppRole.superAdmin);

  // ── Permission checks ──────────────────────────────────────────────────────
  Set<AppPermission> get _effectivePermissions {
    final effectiveRoles = _activeRole != null ? [_activeRole] : _roles;
    return {
      for (final role in effectiveRoles)
        ...rolePermissions[role] ?? {},
    };
  }

  bool hasPermission(AppPermission permission) =>
      _effectivePermissions.contains(permission);

  bool hasAllPermissions(List<AppPermission> permissions) =>
      permissions.every(hasPermission);

  bool hasAnyPermission(List<AppPermission> permissions) =>
      permissions.any(hasPermission);

  // ── Screen access guards ───────────────────────────────────────────────────
  bool canAccessScreen(String screenName) => switch (screenName) {
    'plants'        => hasPermission(AppPermission.plantsRead),
    'nurseries'     => hasPermission(AppPermission.nurseriesRead),
    'inventory'     => hasPermission(AppPermission.inventoryRead),
    'requests'      => hasAnyPermission([
                         AppPermission.requestCreate,
                         AppPermission.requestRead,
                       ]),
    'orders'        => hasPermission(AppPermission.ordersRead),
    'payments'      => hasPermission(AppPermission.paymentsRead),
    'dispatches'    => hasPermission(AppPermission.dispatchRead),
    'tracking'      => hasPermission(AppPermission.trackingRead),
    'notifications' => hasPermission(AppPermission.notificationsRead),
    'profile'       => hasPermission(AppPermission.profileRead),
    _               => false,
  };
}
