import '../../domain/rbac/roles.dart';

class Workspace {
  final String type;
  final int? nurseryId;
  final String? nurseryName;

  const Workspace({
    required this.type,
    this.nurseryId,
    this.nurseryName,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        type: json['type'] as String? ?? 'PERSONAL',
        nurseryId: (json['nursery_id'] as num?)?.toInt(),
        nurseryName: json['nursery_name'] as String?,
      );

  bool get isBusinessWorkspace => type != 'PERSONAL';

  AppRole get appRole => switch (type) {
        'OWNED_NURSERY'   => AppRole.nurseryOwner,
        'MANAGER_NURSERY' => AppRole.manager,
        'DRIVER'          => AppRole.driver,
        _                 => AppRole.buyer,
      };

  String get displayTitle => switch (type) {
        'OWNED_NURSERY'   => nurseryName ?? 'My Nursery',
        'MANAGER_NURSERY' => nurseryName ?? 'Manager',
        'DRIVER'          => 'Driver',
        _                 => 'Customer',
      };

  String get roleLabel => switch (type) {
        'OWNED_NURSERY'   => 'Nursery Owner',
        'MANAGER_NURSERY' => 'Manager / Gumastha',
        'DRIVER'          => 'Delivery Driver',
        _                 => 'Customer',
      };
}
