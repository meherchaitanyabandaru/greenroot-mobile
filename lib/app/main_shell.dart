import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/qr_scanner_screen.dart';
import '../features/auth/data/models/capabilities_model.dart';
import '../features/auth/presentation/providers/session_provider.dart';
import '../features/activity/activity_screen.dart';
import '../features/buying/buying_screen.dart';
import '../features/dispatches/dispatch_list_screen.dart';
import '../features/driver_section/driver_screen.dart';
import '../features/driver/trip_preview_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quotations/quotation_list_screen.dart';
import '../features/orders/order_list_screen.dart';
import '../features/selling/selling_screen.dart';

// ── Tab index provider — reset to 0 when role changes ─────────────────────────
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;
    final tabs = _buildTabs(caps);

    // Clamp stored index when tab count changes (e.g. role changed)
    final rawIndex = ref.watch(mainTabIndexProvider);
    final index = rawIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(mainTabIndexProvider.notifier).state = i,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.activeIcon, color: AppColors.primaryMain),
                  label: t.label,
                ))
            .toList(),
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

// ── BRD role → tabs mapping ───────────────────────────────────────────────────
//
// Owner (APPROVED) : Home | Sell | Buy | Activity | Profile
// Manager          : Home | My Work | Dispatches | Profile
// Customer         : Home | Quotations | Orders | Profile
// Driver only      : Home | My Trips | Join Trip | Profile

List<_Tab> _buildTabs(UserCapabilities caps) {
  final home = _Tab(
    screen: const HomeScreen(),
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  );
  final profile = _Tab(
    screen: const ProfileScreen(),
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  );

  // ── Driver-only (no nursery ownership or manager role)
  if (caps.isDriverOnly) {
    return [
      home,
      _Tab(
        screen: const DispatchListScreen(),
        icon: Icons.route_outlined,
        activeIcon: Icons.route_rounded,
        label: 'My Trips',
      ),
      _Tab(
        screen: const _JoinTripTab(),
        icon: Icons.qr_code_scanner_outlined,
        activeIcon: Icons.qr_code_scanner_rounded,
        label: 'Join Trip',
      ),
      profile,
    ];
  }

  // ── Manager (not an owner)
  if (caps.isManager && !caps.isNurseryOwner) {
    return [
      home,
      _Tab(
        screen: const SellingScreen(),
        icon: Icons.work_outline_rounded,
        activeIcon: Icons.work_rounded,
        label: 'My Work',
      ),
      _Tab(
        screen: const DispatchListScreen(),
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        label: 'Dispatches',
      ),
      profile,
    ];
  }

  // ── Nursery Owner (APPROVED)
  if (caps.isNurseryOwner) {
    return [
      home,
      _Tab(
        screen: const SellingScreen(),
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Sell',
      ),
      _Tab(
        screen: const BuyingScreen(),
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag_rounded,
        label: 'Buy',
      ),
      _Tab(
        screen: const ActivityScreen(),
        icon: Icons.timeline_outlined,
        activeIcon: Icons.timeline_rounded,
        label: 'Activity',
      ),
      profile,
    ];
  }

  // ── Default: Customer / Buyer
  return [
    home,
    _Tab(
      screen: const QuotationListScreen(),
      icon: Icons.request_quote_outlined,
      activeIcon: Icons.request_quote_rounded,
      label: 'Quotations',
    ),
    _Tab(
      screen: const OrderListScreen(),
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    profile,
  ];
}

// ── Join Trip tab — shown as a tab for drivers ─────────────────────────────────

class _JoinTripTab extends ConsumerStatefulWidget {
  const _JoinTripTab();

  @override
  ConsumerState<_JoinTripTab> createState() => _JoinTripTabState();
}

class _JoinTripTabState extends ConsumerState<_JoinTripTab> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _openTripPreview(BuildContext context, String code) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripPreviewScreen(code: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Join Trip', style: AppTypography.h3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 44,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text('Join a Delivery Trip',
                style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scan the QR code or enter the trip code shared by the nursery owner or manager.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x3l),

            // Scan QR
            AppButton(
              label: 'Scan Trip QR Code',
              onPressed: () async {
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const QrScannerScreen(title: 'Scan Trip QR'),
                    fullscreenDialog: true,
                  ),
                );
                if (result != null && result.isNotEmpty && context.mounted) {
                  _openTripPreview(context, result);
                }
              },
              leadingIcon: Icons.qr_code_scanner_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Or enter code manually
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('or',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            TextField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                hintText: 'Enter trip code / UUID',
                hintStyle:
                    AppTypography.body.copyWith(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryMain, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.tag_rounded,
                    color: AppColors.textMuted),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () {
                final code = _codeCtrl.text.trim();
                if (code.isNotEmpty) {
                  _openTripPreview(context, code);
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size(double.infinity, AppSpacing.buttonHeight),
                side: const BorderSide(color: AppColors.primaryMain),
                foregroundColor: AppColors.primaryMain,
              ),
              child: const Text('Join with Code'),
            ),
          ],
        ),
      ),
    );
  }
}
