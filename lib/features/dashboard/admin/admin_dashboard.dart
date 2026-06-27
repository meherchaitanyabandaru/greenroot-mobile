import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/session_provider.dart';

class AdminDashboard extends ConsumerWidget {
  final AppRole role;

  const AdminDashboard({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GreenRoot Admin'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            const SizedBox(height: AppSpacing.x3l),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                size: 44,
                color: AppColors.primaryMain,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            Text(
              'Hi ${user?.firstName?.isNotEmpty == true ? user!.firstName : 'Admin'}',
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Admin operations are managed in the GreenRoot web portal. The mobile app is limited to nursery owner, manager, driver, and customer workflows.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),
            OutlinedButton.icon(
              onPressed: () => context.go('/workspace-select'),
              icon: const Icon(Icons.switch_account_outlined),
              label: const Text('Choose Mobile Workspace'),
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size(double.infinity, AppSpacing.buttonHeight),
                side: const BorderSide(color: AppColors.primaryMain),
                foregroundColor: AppColors.primaryMain,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size(double.infinity, AppSpacing.buttonHeight),
                backgroundColor: AppColors.primaryMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
