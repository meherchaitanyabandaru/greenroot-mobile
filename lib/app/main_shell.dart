import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/qr_scanner_screen.dart';
import '../features/auth/data/models/capabilities_model.dart';
import '../features/auth/presentation/providers/session_provider.dart';
import '../features/buying/buying_screen.dart';
import '../features/dispatches/dispatches.dart';
import '../features/driver/driver_home_screen.dart';
import '../features/driver/driver_trips_screen.dart';
import '../features/driver/trip_preview_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications.dart';
import '../features/profile/profile_screen.dart';
import '../features/selling/selling_screen.dart';

// ── Active tab index (reset to 0 on role change) ──────────────────────────────
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;
    final tabs = _buildTabs(caps);

    final rawIndex = ref.watch(mainTabIndexProvider);
    final index = rawIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: caps.isDriverOnly
          ? _DriverBottomNav(
              tabs: tabs,
              selectedIndex: index,
              onSelected: (i) =>
                  ref.read(mainTabIndexProvider.notifier).state = i,
            )
          : _GreenRootBottomNav(
              tabs: tabs,
              selectedIndex: index,
              onSelected: (i) =>
                  ref.read(mainTabIndexProvider.notifier).state = i,
            ),
      floatingActionButton:
          caps.isDriverOnly ? null : _buildFab(context, ref, caps),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── Tab descriptor ─────────────────────────────────────────────────────────────

class _Tab {
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({
    required this.screen,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ── Role → tab mapping ────────────────────────────────────────────────────────
//
// Owner   : Home | Buying | Selling | Profile
// Manager : Home | Work              | Profile
// Driver  : Home | Driver            | Profile  (+ center QR scan)
// Customer: Home | Buying            | Profile

List<_Tab> _buildTabs(UserCapabilities caps) {
  const home = _Tab(
    screen: HomeScreen(),
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  );
  const profile = _Tab(
    screen: ProfileScreen(),
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  );

  // ── Driver only (no nursery / manager role)
  // Navigation: Home | Driver | Profile
  if (caps.isDriverOnly) {
    return [
      const _Tab(
        screen: DriverHomeScreen(),
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      const _Tab(
        screen: DriverTripsScreen(),
        icon: Icons.route_outlined,
        activeIcon: Icons.route_rounded,
        label: 'Driver',
      ),
      profile,
    ];
  }

  // ── Manager (not an owner): no Buying tab — managers work at a nursery, they don't buy
  if (caps.isManager && !caps.isNurseryOwner) {
    return [
      home,
      const _Tab(
        screen: SellingScreen(),
        icon: Icons.work_outline_rounded,
        activeIcon: Icons.work_rounded,
        label: 'Work',
      ),
      profile,
    ];
  }

  // ── Nursery Owner
  if (caps.isNurseryOwner) {
    return [
      home,
      const _Tab(
        screen: BuyingScreen(),
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag_rounded,
        label: 'Buying',
      ),
      const _Tab(
        screen: SellingScreen(),
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Selling',
      ),
      profile,
    ];
  }

  // ── Customer / Buyer (default)
  return [
    home,
    const _Tab(
      screen: BuyingScreen(),
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag_rounded,
      label: 'Buying',
    ),
    profile,
  ];
}

// ── FAB per role ──────────────────────────────────────────────────────────────

Widget? _buildFab(
  BuildContext context,
  WidgetRef ref,
  UserCapabilities caps,
) {
  // Driver: contextual FAB — depends on active trip state
  if (caps.isDriverOnly) {
    Widget scanFab() => FloatingActionButton(
          heroTag: 'fab_driver_scan',
          backgroundColor: AppColors.primaryMain,
          foregroundColor: Colors.white,
          tooltip: 'Scan Trip QR',
          onPressed: () async {
            final code = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => const QrScannerScreen(title: 'Scan Trip QR'),
                fullscreenDialog: true,
              ),
            );
            if (code != null && code.isNotEmpty && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TripPreviewScreen(code: code),
                ),
              );
            }
          },
          child: const Icon(Icons.qr_code_scanner_rounded),
        );

    final activeTripAsync = ref.watch(activeDriverTripProvider);
    return activeTripAsync.when(
      loading: () => null,
      error: (_, __) => scanFab(),
      data: (activeTripState) {
        final trip = activeTripState.trip;
        if (trip == null) return scanFab();
        final status = trip.status;
        if (status == 'ACCEPTED' || status == 'DISPATCHED') {
          return FloatingActionButton.extended(
            heroTag: 'fab_driver_view',
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            onPressed: () => context.push('/driver/trip/${trip.id}'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('View Trip'),
          );
        }
        if (status == 'IN_TRANSIT') {
          return FloatingActionButton.extended(
            heroTag: 'fab_driver_event',
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            onPressed: () => context.push('/driver/trips/${trip.id}/event'),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Add Event'),
          );
        }
        return null;
      },
    );
  }

  // Owner FAB
  if (caps.isNurseryOwner) {
    return FloatingActionButton(
      heroTag: 'fab_owner',
      backgroundColor: AppColors.primaryMain,
      foregroundColor: Colors.white,
      tooltip: 'Create',
      onPressed: () => _showOwnerFabSheet(context, ref),
      child: const Icon(Icons.add_rounded),
    );
  }

  // Manager FAB
  if (caps.isManager) {
    return FloatingActionButton(
      heroTag: 'fab_manager',
      backgroundColor: AppColors.primaryMain,
      foregroundColor: Colors.white,
      tooltip: 'Create',
      onPressed: () => _showManagerFabSheet(context, ref),
      child: const Icon(Icons.add_rounded),
    );
  }

  // Customer actions live in onboarding/profile/home, not as a global action.
  return null;
}

// ── FAB action sheets ─────────────────────────────────────────────────────────

void _showOwnerFabSheet(BuildContext context, WidgetRef ref) {
  _showFabSheet(
    context,
    title: 'Create',
    actions: [
      _FabAction(
        icon: Icons.add_shopping_cart_rounded,
        title: 'Create Order',
        subtitle: 'New selling order for a customer',
        onTap: () => context.push('/orders/create'),
      ),
      _FabAction(
        icon: Icons.request_quote_outlined,
        title: 'Create Quotation',
        subtitle: 'Send a price quote to a customer',
        onTap: () => context.push('/quotations/create'),
      ),
      _FabAction(
        icon: Icons.eco_outlined,
        title: 'Plant Request',
        subtitle: 'Request plants from nearby nurseries',
        onTap: () => context.push('/requests/create'),
      ),
    ],
  );
}

void _showManagerFabSheet(BuildContext context, WidgetRef ref) {
  _showFabSheet(
    context,
    title: 'Create',
    actions: [
      _FabAction(
        icon: Icons.add_shopping_cart_rounded,
        title: 'Create Order',
        subtitle: 'New selling order for a customer',
        onTap: () => context.push('/orders/create'),
      ),
      _FabAction(
        icon: Icons.request_quote_outlined,
        title: 'Create Quotation',
        subtitle: 'Send a price quote to a customer',
        onTap: () => context.push('/quotations/create'),
      ),
      _FabAction(
        icon: Icons.eco_outlined,
        title: 'Plant Request',
        subtitle: 'Request plants from nearby nurseries',
        onTap: () => context.push('/requests/create'),
      ),
      _FabAction(
        icon: Icons.local_shipping_outlined,
        title: 'Create Dispatch',
        subtitle: 'Create delivery after loading is complete',
        onTap: () => context.push('/orders?status=LOADED'),
      ),
    ],
  );
}

void _showFabSheet(
  BuildContext context, {
  required String title,
  required List<_FabAction> actions,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FabBottomSheet(title: title, actions: actions),
  );
}

// ── FAB bottom sheet ──────────────────────────────────────────────────────────

class _FabAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FabAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _FabBottomSheet extends StatelessWidget {
  final String title;
  final List<_FabAction> actions;

  const _FabBottomSheet({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppTypography.h3),
            ),
          ),
          const SizedBox(height: 12),
          ...actions.map(
            (a) => _FabActionTile(
              action: a,
              onTap: () {
                Navigator.of(context).pop();
                a.onTap();
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _FabActionTile extends StatelessWidget {
  final _FabAction action;
  final VoidCallback onTap;

  const _FabActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(action.icon, color: AppColors.primaryMain),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.title, style: AppTypography.h4),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

// ── Driver bottom nav with center scan action ─────────────────────────────────
// Layout: Home | Driver | [Scan] | Profile

class _DriverBottomNav extends StatelessWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DriverBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // tabs[0]=Home  tabs[1]=Driver  tabs[2]=Profile
    Future<void> scanQr() async {
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const QrScannerScreen(title: 'Scan Trip QR'),
          fullscreenDialog: true,
        ),
      );
      if (code != null && code.isNotEmpty && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripPreviewScreen(code: code)),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              // Home
              Expanded(
                child: _BottomNavItem(
                  tab: tabs[0],
                  selected: selectedIndex == 0,
                  unreadCount: 0,
                  onTap: () => onSelected(0),
                ),
              ),
              // Trips
              Expanded(
                child: _BottomNavItem(
                  tab: tabs[1],
                  selected: selectedIndex == 1,
                  unreadCount: 0,
                  onTap: () => onSelected(1),
                ),
              ),
              // Center scan button
              Expanded(
                child: _CenterScanButton(onTap: scanQr),
              ),
              // Profile
              Expanded(
                child: _BottomNavItem(
                  tab: tabs[2],
                  selected: selectedIndex == 2,
                  unreadCount: 0,
                  onTap: () => onSelected(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryMain.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standard bottom nav (non-driver roles) ────────────────────────────────────

class _GreenRootBottomNav extends ConsumerWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _GreenRootBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationListProvider).unreadCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    tab: tabs[i],
                    selected: selectedIndex == i,
                    unreadCount: tabs[i].label == 'Alerts' ||
                            tabs[i].label == 'Notifications'
                        ? unread
                        : 0,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.tab,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryMain : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge.count(
            count: unreadCount,
            isLabelVisible: unreadCount > 0,
            child: Icon(
              selected ? tab.activeIcon : tab.icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            tab.label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 28 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}
