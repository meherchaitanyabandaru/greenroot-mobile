enum AppRole {
  admin('ADMIN'),
  superAdmin('SUPER_ADMIN'),
  nurseryOwner('NURSERY_OWNER'),
  manager('MANAGER'),
  driver('DRIVER'),
  buyer('BUYER'),
  transportProvider('TRANSPORT_PROVIDER');

  final String value;
  const AppRole(this.value);

  static AppRole? fromString(String? value) {
    if (value == null) return null;
    return AppRole.values.where((r) => r.value == value.toUpperCase()).firstOrNull;
  }

  String get displayName => switch (this) {
    AppRole.admin            => 'Admin',
    AppRole.superAdmin       => 'Super Admin',
    AppRole.nurseryOwner     => 'Nursery Owner',
    AppRole.manager          => 'Manager',
    AppRole.driver           => 'Driver',
    AppRole.buyer            => 'Buyer',
    AppRole.transportProvider => 'Transport Provider',
  };

  bool get isMobileRole => true; // all roles have mobile access (admin gets limited view)
}

extension AppRoleListX on List<AppRole> {
  bool hasRole(AppRole role) => contains(role);
  bool hasAnyRole(List<AppRole> roles) => roles.any(contains);

  /// Returns the primary role to display (best match for navigation).
  AppRole? get primaryRole {
    const priority = [
      AppRole.nurseryOwner,
      AppRole.manager,
      AppRole.driver,
      AppRole.transportProvider,
      AppRole.buyer,
      AppRole.admin,
      AppRole.superAdmin,
    ];
    for (final role in priority) {
      if (contains(role)) return role;
    }
    return firstOrNull;
  }
}
