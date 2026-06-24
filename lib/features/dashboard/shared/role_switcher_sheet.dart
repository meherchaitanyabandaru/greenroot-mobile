import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/domain/rbac/roles.dart';

class RoleSwitcherSheet extends StatelessWidget {
  final List<AppRole> roles;
  final AppRole currentRole;
  final void Function(AppRole) onSelect;

  const RoleSwitcherSheet({
    super.key,
    required this.roles,
    required this.currentRole,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.x2l,
          AppSpacing.screenPadding,
          AppSpacing.x2l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Switch Role', style: AppTypography.h3),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Select which role to use',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.x2l),
            ...roles.map((role) => _RoleTile(
                  role: role,
                  isActive: role == currentRole,
                  onTap: () => onSelect(role),
                ),),
          ],
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final AppRole role;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: isActive ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? AppColors.primaryMain : AppColors.border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryMain : AppColors.slate100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _roleIcon(role),
                    size: 20,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(role.displayName, style: AppTypography.h4),
                ),
                if (isActive)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryMain,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(AppRole r) => switch (r) {
        AppRole.nurseryOwner => Icons.store_rounded,
        AppRole.manager      => Icons.manage_accounts_rounded,
        AppRole.driver       => Icons.local_shipping_rounded,
        AppRole.buyer        => Icons.shopping_bag_rounded,
        AppRole.transportProvider => Icons.directions_bus_rounded,
        AppRole.admin        => Icons.admin_panel_settings_rounded,
        AppRole.superAdmin   => Icons.security_rounded,
      };
}
