import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/workspace_model.dart';
import '../../domain/rbac/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class WorkspaceSelectScreen extends ConsumerStatefulWidget {
  const WorkspaceSelectScreen({super.key});

  @override
  ConsumerState<WorkspaceSelectScreen> createState() =>
      _WorkspaceSelectScreenState();
}

class _WorkspaceSelectScreenState extends ConsumerState<WorkspaceSelectScreen> {
  Workspace? _selected;

  @override
  void initState() {
    super.initState();
    final workspaces = ref.read(sessionProvider).mobileWorkspaces;
    if (workspaces.isEmpty) return;
    final savedRole = ref.read(activeRoleProvider);
    if (savedRole != null) {
      _selected = workspaces.firstWhere(
        (w) => w.appRole == savedRole,
        orElse: () => workspaces.first,
      );
    } else {
      _selected = workspaces.first;
    }
    // Single workspace: skip the picker and auto-navigate.
    if (workspaces.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirm(),);
    }
  }

  Future<void> _confirm() async {
    final ws = _selected;
    if (ws == null) return;
    await ref.read(activeRoleProvider.notifier).selectRole(ws.appRole);
    ref.read(sessionProvider.notifier).setActiveRole(ws.appRole);
    if (!mounted) return;
    context.go(_routeFor(ws.appRole));
  }

  String _routeFor(AppRole role) => switch (role) {
        AppRole.nurseryOwner => '/home/nursery-owner',
        AppRole.manager => '/home/manager',
        AppRole.driver => '/home/driver',
        AppRole.admin => '/home/admin',
        _ => '/home/buyer',
      };

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final workspaces = session.mobileWorkspaces;
    final user = session.user;

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
                user?.firstName != null
                    ? 'Hello, ${user!.firstName}!'
                    : 'Hello!',
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You have multiple roles. Choose a workspace to continue.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3l),

              // Workspace cards
              Expanded(
                child: workspaces.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.work_off_outlined,
                                size: 52, color: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No workspaces found.',
                              style: AppTypography.body
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: () => context.go('/home/buyer'),
                              child: const Text('Continue as Customer'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: workspaces.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final ws = workspaces[i];
                          final isSelected = _selected == ws;
                          return _WorkspaceCard(
                            workspace: ws,
                            isSelected: isSelected,
                            onTap: () => setState(() => _selected = ws),
                          );
                        },
                      ),
              ),

              const SizedBox(height: AppSpacing.x2l),
              AppButton(
                label: _selected != null
                    ? 'Continue as ${_selected!.roleLabel}'
                    : 'Select a workspace',
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
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
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

class _WorkspaceCard extends StatelessWidget {
  final Workspace workspace;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorkspaceCard({
    required this.workspace,
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryMain : AppColors.forest100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                _iconFor(workspace.type),
                color: isSelected ? Colors.white : AppColors.primaryMain,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workspace.displayTitle, style: AppTypography.h4),
                  const SizedBox(height: 2),
                  Text(
                    workspace.roleLabel,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
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

  IconData _iconFor(String type) => switch (type) {
        'OWNED_NURSERY' => Icons.local_florist_outlined,
        'MANAGER_NURSERY' => Icons.manage_accounts_outlined,
        'DRIVER' => Icons.local_shipping_outlined,
        _ => Icons.shopping_bag_outlined,
      };
}
