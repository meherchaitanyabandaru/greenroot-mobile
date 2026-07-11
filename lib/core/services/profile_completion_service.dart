import '../widgets/profile_completion_card.dart';
import '../../features/auth/data/models/capabilities_model.dart';
import '../../features/auth/data/models/user_models.dart';
import '../../features/auth/domain/rbac/roles.dart';
import '../../features/nurseries/nurseries.dart';

/// Minimum completion fraction to suppress the 90% popup.
const double kCompletionThreshold = 0.90;

/// Builds role-specific completion items.
///
/// Each role has a tailored checklist. Items marked [done] contribute to the
/// completion percentage. The caller supplies whatever data is available —
/// passing null for optional data simply marks those items incomplete rather
/// than crashing.
List<CompletionItem> buildCompletionItems({
  required AppRole role,
  required UserProfile? user,
  required UserCapabilities caps,
  Nursery? nursery,

  // Navigation callbacks — null means no CTA shown on that row
  void Function()? onEditProfile,
  void Function()? onEditAddress,
  void Function()? onEditNurseryProfile,
  void Function()? onRegisterDriver,
}) {
  switch (role) {
    case AppRole.nurseryOwner:
      return _ownerItems(
        user,
        caps,
        nursery,
        onEditProfile: onEditProfile,
        onEditAddress: onEditAddress,
        onEditNurseryProfile: onEditNurseryProfile,
      );
    case AppRole.manager:
      return _managerItems(user, caps, onEditProfile: onEditProfile);
    case AppRole.driver:
      return _driverItems(
        user,
        caps,
        onEditProfile: onEditProfile,
        onRegisterDriver: onRegisterDriver,
      );
    case AppRole.buyer:
      return _buyerItems(user, onEditProfile: onEditProfile);
    default:
      return _buyerItems(user, onEditProfile: onEditProfile);
  }
}

double completionPercent(List<CompletionItem> items) {
  if (items.isEmpty) return 1.0;
  return items.where((i) => i.done).length / items.length;
}

bool needsCompletionPrompt(List<CompletionItem> items) =>
    completionPercent(items) < kCompletionThreshold;

// ─── Per-role builders ────────────────────────────────────────────────────────

/// NURSERY_OWNER — 8 items
/// • name, last name, email, profile photo, gender        (5 personal)
/// • nursery active, address, description                 (3 nursery)
List<CompletionItem> _ownerItems(
  UserProfile? user,
  UserCapabilities caps,
  Nursery? nursery, {
  void Function()? onEditProfile,
  void Function()? onEditAddress,
  void Function()? onEditNurseryProfile,
}) {
  final hasAddress = nursery != null && nursery.addresses.isNotEmpty;
  final hasDescription =
      nursery != null && (nursery.description?.isNotEmpty ?? false);

  return [
    CompletionItem(
      label: 'Add your first name',
      done: user?.hasRealFirstName ?? false,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add your last name',
      done: (user?.lastName?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add email address',
      done: (user?.email?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Upload profile photo',
      done: user?.profileImageUrl != null,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Set your gender',
      done: (user?.gender?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Nursery approved',
      done: caps.isNurseryOwner,
    ),
    CompletionItem(
      label: 'Add nursery address',
      done: hasAddress,
      onTap: onEditAddress,
    ),
    CompletionItem(
      label: 'Add nursery description',
      done: hasDescription,
      onTap: onEditNurseryProfile,
    ),
  ];
}

/// MANAGER — 6 items
/// • name, last name, email, photo, gender   (5 personal)
/// • joined a nursery                         (1 role)
List<CompletionItem> _managerItems(
  UserProfile? user,
  UserCapabilities caps, {
  void Function()? onEditProfile,
}) {
  return [
    CompletionItem(
      label: 'Add your first name',
      done: user?.hasRealFirstName ?? false,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add your last name',
      done: (user?.lastName?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add email address',
      done: (user?.email?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Upload profile photo',
      done: user?.profileImageUrl != null,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Set your gender',
      done: (user?.gender?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Joined a nursery as manager',
      done: caps.isManager,
    ),
  ];
}

/// DRIVER — 6 items
/// • name, last name, email, photo, gender   (5 personal)
/// • driver profile submitted                 (1 role)
List<CompletionItem> _driverItems(
  UserProfile? user,
  UserCapabilities caps, {
  void Function()? onEditProfile,
  void Function()? onRegisterDriver,
}) {
  return [
    CompletionItem(
      label: 'Add your first name',
      done: user?.hasRealFirstName ?? false,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add your last name',
      done: (user?.lastName?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add email address',
      done: (user?.email?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Upload profile photo',
      done: user?.profileImageUrl != null,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Set your gender',
      done: (user?.gender?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Submit driver profile',
      done: caps.hasDriverProfile,
      onTap: caps.hasDriverProfile ? null : onRegisterDriver,
    ),
  ];
}

/// BUYER — 5 items
/// • name, last name, email, photo, gender   (5 personal)
List<CompletionItem> _buyerItems(
  UserProfile? user, {
  void Function()? onEditProfile,
}) {
  return [
    CompletionItem(
      label: 'Add your first name',
      done: user?.hasRealFirstName ?? false,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add your last name',
      done: (user?.lastName?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Add email address',
      done: (user?.email?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Upload profile photo',
      done: user?.profileImageUrl != null,
      onTap: onEditProfile,
    ),
    CompletionItem(
      label: 'Set your gender',
      done: (user?.gender?.isNotEmpty ?? false),
      onTap: onEditProfile,
    ),
  ];
}
