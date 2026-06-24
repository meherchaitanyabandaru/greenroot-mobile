import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/domain/rbac/permissions.dart';
import '../../../features/auth/domain/rbac/roles.dart';
import '../../../features/auth/presentation/providers/session_provider.dart';

class PermissionGuard extends ConsumerWidget {
  final Widget child;
  final AppPermission? permission;
  final AppRole? role;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.child,
    this.permission,
    this.role,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permSvc = ref.watch(permissionServiceProvider);

    bool allowed = true;
    if (permission != null) allowed = permSvc.hasPermission(permission!);
    if (role != null) allowed = allowed && permSvc.hasRole(role!);

    if (!allowed) return fallback ?? const _AccessDenied();
    return child;
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.red100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: AppColors.red600,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text('Access Denied', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You do not have permission to view this screen.',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
