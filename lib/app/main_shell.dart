import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/profile_completion_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/profile_completion_prompt.dart';
import '../features/auth/data/models/capabilities_model.dart';
import '../features/auth/domain/rbac/roles.dart';
import '../features/auth/presentation/providers/session_provider.dart';
import '../features/buying/buying_screen.dart';
import '../features/drivers/driver_home_screen.dart'
    show DriverHomeScreen, driverHasActiveTripProvider;
import '../features/drivers/driver_trips_screen.dart';
import '../core/widgets/universal_qr_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications.dart';
import '../features/nurseries/nurseries.dart';
import '../features/selling/selling_screen.dart';
import '../features/market/local_market_screen.dart';

// ── Active tab index (reset to 0 on role change) ──────────────────────────────
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Show the completion prompt once per cold start after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPrompt());
  }

  Future<void> _maybeShowPrompt() async {
    if (!mounted) return;
    final alreadyShown = ref.read(completionPromptShownProvider);
    if (alreadyShown) return;

    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) return;

    final role = session.capabilities.canSell
        ? (session.capabilities.isNurseryOwner
            ? AppRole.nurseryOwner
            : AppRole.manager)
        : session.capabilities.hasDriverProfile
            ? AppRole.driver
            : AppRole.buyer;

    // For owners: try to load nursery data for branding + address checks.
    Nursery? nursery;
    final nurseryId = session.capabilities.primaryNurseryId;
    if (nurseryId != null) {
      try {
        nursery =
            await ref.read(nurseryRepositoryProvider).getNursery(nurseryId);
      } catch (_) {}
    }

    if (!mounted) return;

    final items = buildCompletionItems(
      role: role,
      user: session.user,
      caps: session.capabilities,
      nursery: nursery,
      onEditProfile: () => context.push('/edit-profile'),
      onEditAddress: nurseryId != null
          ? () => context.push('/nursery/addresses', extra: nurseryId)
          : null,
        onRegisterDriver: () => context.push('/register/driver'),
    );

    final pct = completionPercent(items);
    if (!needsCompletionPrompt(items)) return;

    if (!mounted) return;
    await showCompletionPrompt(
      context,
      ref,
      items: items,
      percent: pct,
      onCompleteNow: () {
        if (!mounted) return;
        context.push('/complete-profile');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
// Owner   : Home | Buying | Selling | Local Market
// Manager : Home | Work   | Local Market
// Driver  : Home | Driver  (+ center QR scan)
// Customer: Home | Buying

List<_Tab> _buildTabs(UserCapabilities caps) {
  const home = _Tab(
    screen: HomeScreen(),
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  );

  // ── Driver only (no nursery / manager role)
  // Navigation: Home | Driver  (+ center scan button in nav bar)
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
        label: 'Trips',
      ),
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
      const _Tab(
        screen: LocalMarketScreen(),
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Market',
      ),
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
      const _Tab(
        screen: LocalMarketScreen(),
        icon: Icons.store_mall_directory_outlined,
        activeIcon: Icons.store_mall_directory_rounded,
        label: 'Market',
      ),
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
  ];
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

// ── Driver bottom nav with center scan action ─────────────────────────────────
// Layout: Home | [Scan] | Driver

class _DriverBottomNav extends ConsumerWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DriverBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // tabs[0]=Home  tabs[1]=Driver
    final hasActiveTrip = ref.watch(driverHasActiveTripProvider);

    void scanQr() {
      if (hasActiveTrip) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have an active trip. Complete your delivery before scanning for a new one.',
            ),
            backgroundColor: AppColors.red600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const UniversalQrScreen(),
          fullscreenDialog: true,
        ),
      );
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
              // Center scan button
              Expanded(
                child: _CenterScanButton(onTap: scanQr),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryMain.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan',
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryMain,
              fontWeight: FontWeight.w700,
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

  // Rounded-up midpoint: scan button sits after this many tabs on the left.
  // 2 tabs → 1   [A][Scan][B]
  // 3 tabs → 2   [A][B][Scan][C]
  // 4 tabs → 2   [A][B][Scan][C][D]
  int get _split => (tabs.length + 1) ~/ 2;

  void _openScan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UniversalQrScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationListProvider).unreadCount;

    int unreadFor(int i) =>
        tabs[i].label == 'Alerts' || tabs[i].label == 'Notifications'
            ? unread
            : 0;

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
              for (var i = 0; i < _split; i++)
                Expanded(
                  child: _BottomNavItem(
                    tab: tabs[i],
                    selected: selectedIndex == i,
                    unreadCount: unreadFor(i),
                    onTap: () => onSelected(i),
                  ),
                ),
              Expanded(child: _CenterScanButton(onTap: () => _openScan(context))),
              for (var i = _split; i < tabs.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    tab: tabs[i],
                    selected: selectedIndex == i,
                    unreadCount: unreadFor(i),
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
