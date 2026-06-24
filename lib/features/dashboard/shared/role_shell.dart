import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/domain/rbac/roles.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/session_provider.dart';
import '../../notifications/notifications.dart';
import 'role_switcher_sheet.dart';

final roleTabIndexProvider =
    StateProvider.family<int, AppRole>((ref, role) => 0);

class RoleNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  const RoleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}

class RoleShell extends ConsumerStatefulWidget {
  final List<RoleNavItem> navItems;
  final AppRole role;

  const RoleShell({
    super.key,
    required this.navItems,
    required this.role,
  });

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  @override
  Widget build(BuildContext context) {
    final session  = ref.watch(sessionProvider);
    final user     = session.user;
    final allRoles = session.roles.where((r) => r.isMobileRole).toList();
    final index    = ref.watch(roleTabIndexProvider(widget.role));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: _GrTitle(role: widget.role),
        actions: [
          Consumer(
            builder: (_, ref, __) {
              final notifState = ref.watch(notificationListProvider);
              final unread = notifState.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.red600,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (allRoles.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch Role',
              onPressed: () => _switchRole(context, allRoles),
            ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'logout') {
                ref.read(sessionProvider.notifier).logout().then((_) {
                  if (context.mounted) context.go('/login');
                });
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                enabled: false,
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      user?.name ?? 'Profile',
                      style: AppTypography.body,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 18, color: AppColors.red600),
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
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _Avatar(initials: user?.initials ?? '?'),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: widget.navItems.map((item) => item.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) =>
            ref.read(roleTabIndexProvider(widget.role).notifier).state = i,
        items: widget.navItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  void _switchRole(BuildContext ctx, List<AppRole> roles) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RoleSwitcherSheet(
        roles: roles,
        currentRole: widget.role,
        onSelect: (role) {
          Navigator.pop(ctx);
          ref.read(activeRoleProvider.notifier).selectRole(role).then((_) {
            if (ctx.mounted) {
              ctx.go('/home/${role.value.toLowerCase().replaceAll('_', '-')}');
            }
          });
        },
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _GrTitle extends StatelessWidget {
  final AppRole role;
  const _GrTitle({required this.role});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
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
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GreenRoot', style: AppTypography.h4),
            Text(
              role.displayName,
              style: AppTypography.caption
                  .copyWith(color: AppColors.primaryMain),
            ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryMain, width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.label.copyWith(
            color: AppColors.primaryMain,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Placeholder feature screen ───────────────────────────────────────────────

class PlaceholderFeatureScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;

  const PlaceholderFeatureScreen({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle = 'This feature is coming soon.',
  });

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
                  color: AppColors.forest100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppColors.primaryMain),
              ),
              const SizedBox(height: AppSpacing.x2l),
              Text(title, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentMain.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'In development',
                  style: AppTypography.label.copyWith(
                    color: AppColors.forest800,
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
