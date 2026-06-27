import 'workspace_model.dart';
import '../../domain/rbac/roles.dart';

class UserCapabilities {
  final bool isNurseryOwner;
  final bool isManager;
  final bool hasDriverProfile;
  final bool hasPendingNursery;
  final bool hasRejectedNursery;
  final int? ownedNurseryId;
  final String? ownedNurseryName;
  final String? ownedNurseryStatus;
  final List<Workspace> managedNurseries;

  const UserCapabilities({
    this.isNurseryOwner = false,
    this.isManager = false,
    this.hasDriverProfile = false,
    this.hasPendingNursery = false,
    this.hasRejectedNursery = false,
    this.ownedNurseryId,
    this.ownedNurseryName,
    this.ownedNurseryStatus,
    this.managedNurseries = const [],
  });

  bool get canSell => isNurseryOwner || isManager;

  // True when the user is a driver AND has no selling or buying context.
  // Per BRD: drivers should not see Buy or Sell tabs.
  bool get isDriverOnly => hasDriverProfile && !isNurseryOwner && !isManager;

  int? get primaryNurseryId =>
      ownedNurseryId ?? managedNurseries.firstOrNull?.nurseryId;

  String? get primaryNurseryName =>
      ownedNurseryName ?? managedNurseries.firstOrNull?.nurseryName;

  factory UserCapabilities.fromWorkspaces(
    List<Workspace> workspaces, {
    String? ownedNurseryStatus,
    AppRole? activeRole,
  }) {
    final roleWorkspaces = activeRole == null
        ? workspaces
        : workspaces.where((w) => w.appRole == activeRole).toList();
    Workspace? owned;
    for (final w in roleWorkspaces) {
      if (w.type == 'OWNED_NURSERY') {
        owned = w;
        break;
      }
    }
    final managed =
        roleWorkspaces.where((w) => w.type == 'MANAGER_NURSERY').toList();
    final status = ownedNurseryStatus?.toUpperCase();
    final isApproved =
        owned != null && (status == 'APPROVED' || status == 'ACTIVE');
    final isPending = owned != null && status == 'PENDING';
    final isRejected = owned != null && status == 'REJECTED';

    return UserCapabilities(
      isNurseryOwner: isApproved,
      isManager: managed.isNotEmpty,
      hasDriverProfile: roleWorkspaces.any((w) => w.type == 'DRIVER'),
      hasPendingNursery: isPending,
      hasRejectedNursery: isRejected,
      ownedNurseryId: owned?.nurseryId,
      ownedNurseryName: owned?.nurseryName,
      ownedNurseryStatus: status,
      managedNurseries: managed,
    );
  }

  static const UserCapabilities empty = UserCapabilities();
}
