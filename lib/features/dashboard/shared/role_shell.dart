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
  /// If false, item appears in the drawer but NOT in the bottom nav bar.
  final bool inBottomNav;

  const RoleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
    this.inBottomNav = true,
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final session  = ref.watch(sessionProvider);
    final user     = session.user;
    final allRoles = session.roles.where((r) => r.isMobileRole).toList();
    final index    = ref.watch(roleTabIndexProvider(widget.role));

    // Bottom nav uses only items with inBottomNav == true.
    final bottomEntries = widget.navItems
        .asMap()
        .entries
        .where((e) => e.value.inBottomNav)
        .toList();
    final bottomToFull = bottomEntries.map((e) => e.key).toList();
    final bottomIndex  = bottomToFull.indexOf(index).clamp(0, bottomEntries.length - 1);

    final notifState = ref.watch(notificationListProvider);
    final unreadCount = notifState.unreadCount;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _GrTitle(role: widget.role),
        actions: [
          // Notification bell
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
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
                        unreadCount > 9 ? '9+' : '$unreadCount',
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
          ),
          // Avatar opens drawer
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _Avatar(initials: user?.initials ?? '?'),
            ),
          ),
        ],
      ),
      drawer: _AppDrawer(
        role: widget.role,
        navItems: widget.navItems,
        currentIndex: index,
        user: user,
        allRoles: allRoles,
        unreadCount: unreadCount,
        onItemTap: (i) {
          Navigator.of(context).pop();
          ref.read(roleTabIndexProvider(widget.role).notifier).state = i;
        },
        onNotifications: () {
          Navigator.of(context).pop();
          context.push('/notifications');
        },
        onSwitchRole: allRoles.length > 1
            ? () {
                Navigator.of(context).pop();
                _switchRole(context, allRoles);
              }
            : null,
        onSignOut: () {
          Navigator.of(context).pop();
          ref.read(sessionProvider.notifier).logout().then((_) {
            if (context.mounted) context.go('/login');
          });
        },
      ),
      body: IndexedStack(
        index: index,
        children: widget.navItems.map((item) => item.screen).toList(),
      ),
      bottomNavigationBar: bottomEntries.length < 2
          ? null
          : _BottomNav(
              items: bottomEntries.map((e) => e.value).toList(),
              currentIndex: bottomIndex,
              onTap: (i) {
                ref
                    .read(roleTabIndexProvider(widget.role).notifier)
                    .state = bottomToFull[i];
              },
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

// ── Navigation Drawer ─────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final AppRole role;
  final List<RoleNavItem> navItems;
  final int currentIndex;
  final dynamic user; // UserProfile?
  final List<AppRole> allRoles;
  final int unreadCount;
  final void Function(int) onItemTap;
  final VoidCallback onNotifications;
  final VoidCallback? onSwitchRole;
  final VoidCallback onSignOut;

  const _AppDrawer({
    required this.role,
    required this.navItems,
    required this.currentIndex,
    required this.user,
    required this.allRoles,
    required this.unreadCount,
    required this.onItemTap,
    required this.onNotifications,
    required this.onSwitchRole,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _DrawerHeader(user: user, role: role),

          // ── Nav items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...navItems.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final isActive = currentIndex == i;
                  return _DrawerNavTile(
                    icon: item.icon,
                    activeIcon: item.activeIcon,
                    label: item.label,
                    isActive: isActive,
                    inBottomNav: item.inBottomNav,
                    onTap: () => onItemTap(i),
                  );
                }),

                const SizedBox(height: AppSpacing.md),
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Text(
                    'MORE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _DrawerActionTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  badge: unreadCount > 0 ? '$unreadCount' : null,
                  onTap: onNotifications,
                ),
                if (onSwitchRole != null)
                  _DrawerActionTile(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Switch Role',
                    onTap: onSwitchRole!,
                  ),
              ],
            ),
          ),

          // ── Sign out ────────────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: AppSpacing.sm),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.red600, size: 18),
              ),
              title: const Text('Sign Out',
                  style: TextStyle(
                    color: AppColors.red600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
              onTap: onSignOut,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final dynamic user;
  final AppRole role;

  const _DrawerHeader({required this.user, required this.role});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'GreenRoot User';
    final initials = user?.initials ?? '?';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.forest900, AppColors.forest700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.only(topRight: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentMain,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.forest950,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role.displayName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool inBottomNav;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.inBottomNav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryMain : AppColors.forest50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isActive ? activeIcon : icon,
            color: isActive ? Colors.white : AppColors.primaryMain,
            size: 18,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primaryMain : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: !inBottomNav
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'menu',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.amber700,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : null,
        onTap: onTap,
        selected: isActive,
        selectedTileColor: AppColors.forest50,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerActionTile({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.red600,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final List<RoleNavItem> items;
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isActive = currentIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive
                            ? AppColors.primaryMain
                            : AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive
                              ? AppColors.primaryMain
                              : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 20 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
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
