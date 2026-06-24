import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/rbac/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  AppRole? _selected;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(activeRoleProvider);
    final roles = ref.read(sessionProvider).roles.where((r) => r.isMobileRole).toList();
    _selected = saved ?? roles.firstOrNull;
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    await ref.read(activeRoleProvider.notifier).selectRole(_selected!);

    if (!mounted) return;
    context.go('/home/${_roleSlug(_selected!)}');
  }

  String _roleSlug(AppRole role) => switch (role) {
    AppRole.buyer              => 'buyer',
    AppRole.nurseryOwner       => 'nursery-owner',
    AppRole.manager            => 'manager',
    AppRole.driver             => 'driver',
    AppRole.transportProvider  => 'transport-provider',
    AppRole.admin              => 'admin',
    AppRole.superAdmin         => 'super-admin',
  };

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final roles = session.roles.where((r) => r.isMobileRole).toList();
    final user  = session.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.x3l),

              // Greeting
              Text(
                user?.name != null ? 'Hello, ${user!.name!.split(' ').first}' : 'Hello!',
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You have multiple roles. Choose how you want to continue.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3l),

              // Role cards
              Expanded(
                child: ListView.separated(
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final role = roles[i];
                    final isSelected = _selected == role;
                    return _RoleCard(
                      role: role,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selected = role),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.x2l),

              AppButton(
                label: 'Continue as ${_selected?.displayName ?? '...'}',
                onPressed: _selected != null ? _confirm : null,
              ),

              TextButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).logout().then((_) {
                    if (context.mounted) context.go('/login');
                  });
                },
                child: Center(
                  child: Text(
                    'Sign out',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final AppRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isSelected ? AppColors.primaryMain : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryMain : AppColors.slate100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                _icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: AppSpacing.iconSizeLg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.displayName, style: AppTypography.h4),
                  Text(_subtitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryMain,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (role) {
    AppRole.buyer              => Icons.shopping_bag_outlined,
    AppRole.nurseryOwner       => Icons.local_florist_outlined,
    AppRole.manager            => Icons.manage_accounts_outlined,
    AppRole.driver             => Icons.local_shipping_outlined,
    AppRole.transportProvider  => Icons.directions_car_outlined,
    AppRole.admin              => Icons.admin_panel_settings_outlined,
    AppRole.superAdmin         => Icons.security_outlined,
  };

  String get _subtitle => switch (role) {
    AppRole.buyer              => 'Browse plants and place orders',
    AppRole.nurseryOwner       => 'Manage your nursery & inventory',
    AppRole.manager            => 'Manage nursery operations',
    AppRole.driver             => 'View and manage deliveries',
    AppRole.transportProvider  => 'Manage transport & dispatch',
    AppRole.admin              => 'Platform administration',
    AppRole.superAdmin         => 'Full platform access',
  };
}
