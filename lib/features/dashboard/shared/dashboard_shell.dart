import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../features/auth/presentation/providers/session_provider.dart';

class DashboardShell extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Future<void> Function() onLogout;

  const DashboardShell({
    super.key,
    required this.title,
    required this.body,
    required this.onLogout,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'GR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTypography.h4),
          ],
        ),
        actions: [
          if (actions != null) ...actions!,
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'logout') await onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(user?.name ?? 'Profile', style: AppTypography.body),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AppColors.red600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sign out',
                      style: AppTypography.body.copyWith(color: AppColors.red600),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: const UserAvatar(size: 34, borderWidth: 1.5),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
