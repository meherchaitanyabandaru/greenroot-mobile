import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dashboard/owner/owner_dashboard_data.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;
    final user = session.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.primaryMain,
                shape: BoxShape.circle,
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
            const SizedBox(width: 8),
            const Text('GreenRoot', style: AppTypography.h4),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(sessionProvider.notifier).bootstrap();
          ref.invalidate(ownerDashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text(
              user?.firstName != null
                  ? 'Hello, ${user!.firstName}!'
                  : 'Hello!',
              style: AppTypography.h1,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'What would you like to do today?',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),

            // Role badges
            if (caps.isNurseryOwner || caps.isManager || caps.hasDriverProfile) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 6,
                children: [
                  if (caps.isNurseryOwner)
                    _RoleBadge(
                        label: 'Nursery Owner',
                        color: AppColors.primaryMain),
                  if (caps.isManager)
                    _RoleBadge(
                        label: 'Manager / Gumastha',
                        color: AppColors.amber600),
                  if (caps.hasDriverProfile)
                    _RoleBadge(
                        label: 'Driver', color: AppColors.forest600),
                ],
              ),
              const SizedBox(height: AppSpacing.x2l),
            ] else
              const SizedBox(height: AppSpacing.lg),

            // Role-specific primary action cards
            ..._buildActionCards(context, ref, caps),
            const SizedBox(height: AppSpacing.x3l),
          ],
        ),
      ),
    );
  }
}

// Returns role-specific cards + optional "Expand Your Access" section.
List<Widget> _buildActionCards(
    BuildContext context, WidgetRef ref, caps) {
  final tabs = ref.read(mainTabIndexProvider.notifier);

  if (caps.isDriverOnly) {
    // Driver: My Trips + Join Trip. No buying cards, no expand-access prompts.
    return [
      _HomeCard(
        icon: Icons.route_rounded,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        title: 'My Trips',
        subtitle: 'View and manage your delivery trips',
        onTap: () => tabs.state = 1,
      ),
      const SizedBox(height: AppSpacing.md),
      _HomeCard(
        icon: Icons.qr_code_scanner_rounded,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        title: 'Join a Trip',
        subtitle: 'Scan or enter a trip code to join a dispatch',
        onTap: () => tabs.state = 2,
      ),
    ];
  }

  if (caps.isManager && !caps.isNurseryOwner) {
    // Manager: My Work + Dispatches
    return [
      _HomeCard(
        icon: Icons.manage_accounts_rounded,
        iconBg: AppColors.amber100,
        iconColor: AppColors.amber700,
        title: caps.primaryNurseryName ?? 'My Nursery',
        subtitle: 'Manage loading, inventory, and quotations',
        onTap: () => tabs.state = 1,
      ),
      const SizedBox(height: AppSpacing.md),
      _HomeCard(
        icon: Icons.local_shipping_rounded,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        title: 'Dispatches',
        subtitle: 'View and manage active delivery dispatches',
        onTap: () => tabs.state = 2,
      ),
      const SizedBox(height: AppSpacing.x2l),
      const Text('Expand Your Access', style: AppTypography.h3),
      const SizedBox(height: AppSpacing.sm),
      if (!caps.hasDriverProfile)
        _ActionTile(
          icon: Icons.local_shipping_outlined,
          title: 'Register as Driver',
          subtitle: 'Apply to become a delivery driver',
          onTap: () => context.push('/register/driver'),
        ),
    ];
  }

  if (caps.isNurseryOwner) {
    final nurseryId = ref.read(sessionProvider).nurseryId;
    final dashboard = ref.watch(ownerDashboardProvider);
    final data = dashboard.valueOrNull ?? OwnerDashboardData.empty;

    return [
      // Nursery header card
      _HomeCard(
        icon: Icons.local_florist_rounded,
        iconBg: AppColors.primaryLight,
        iconColor: AppColors.primaryMain,
        title: caps.ownedNurseryName ?? 'My Nursery',
        subtitle: 'Manage quotations, orders, and inventory',
        onTap: () => tabs.state = 1,
      ),
      const SizedBox(height: AppSpacing.x2l),

      // ── Metrics ─────────────────────────────────────────────────────────
      const Text('Overview', style: AppTypography.h3),
      const SizedBox(height: AppSpacing.md),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.6,
        children: [
          _MetricCard(
            label: 'Sell Orders',
            value: data.sellOrders.total,
            sub: '${data.sellOrders.pending} pending',
            icon: Icons.storefront_outlined,
            iconColor: AppColors.primaryMain,
            iconBg: AppColors.forest100,
            onTap: () => nurseryId != null
                ? context.push('/orders?nursery=$nurseryId')
                : tabs.state = 1,
          ),
          _MetricCard(
            label: 'Buy Orders',
            value: data.buyOrders.total,
            sub: '${data.buyOrders.pending} pending',
            icon: Icons.shopping_bag_outlined,
            iconColor: AppColors.blue600,
            iconBg: AppColors.blue100,
            onTap: () => tabs.state = 2,
          ),
          _MetricCard(
            label: 'Sell Quotes',
            value: data.sellQuotations.total,
            sub: '${data.sellQuotations.pending} pending',
            icon: Icons.request_quote_outlined,
            iconColor: AppColors.teal700,
            iconBg: AppColors.teal100,
            onTap: () => context.push('/quotations'),
          ),
          _MetricCard(
            label: 'Buy Quotes',
            value: data.buyQuotations.total,
            sub: '${data.buyQuotations.pending} pending',
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.amber600,
            iconBg: AppColors.amber100,
            onTap: () => tabs.state = 2,
          ),
          _MetricCard(
            label: 'Inventory',
            value: data.inventory.totalItems,
            sub: '${data.inventory.available} available',
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.primaryMain,
            iconBg: AppColors.forest100,
            onTap: () => context.push('/inventory/add'),
          ),
          _MetricCard(
            label: 'Connections',
            value: data.connections.total,
            sub: '${data.connections.managers}M · ${data.connections.drivers}D · ${data.connections.customers}C',
            icon: Icons.people_outline_rounded,
            iconColor: AppColors.blue600,
            iconBg: AppColors.blue100,
            onTap: () => context.push('/connections'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x2l),

      // ── Connections section ─────────────────────────────────────────────
      Row(
        children: [
          const Expanded(child: Text('Connections', style: AppTypography.h3)),
          TextButton(
            onPressed: () => context.push('/connections'),
            child: const Text('Manage',
                style: TextStyle(color: AppColors.primaryMain)),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      _ConnectionsBar(
        managers: data.connections.managers,
        drivers: data.connections.drivers,
        customers: data.connections.customers,
        onTap: () => context.push('/connections'),
      ),
      const SizedBox(height: AppSpacing.x2l),

      // ── Quick actions ───────────────────────────────────────────────────
      const Text('Quick Actions', style: AppTypography.h3),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _QuickChip(
              label: 'New Quotation',
              icon: Icons.add_comment_outlined,
              onTap: () => context.push('/quotations/create')),
          _QuickChip(
              label: 'New Order',
              icon: Icons.add_shopping_cart_rounded,
              onTap: () => context.push('/orders/create')),
          _QuickChip(
              label: 'Add Inventory',
              icon: Icons.inventory_2_outlined,
              onTap: () => context.push('/inventory/add')),
          if (!caps.hasDriverProfile)
            _QuickChip(
                label: 'Register as Driver',
                icon: Icons.local_shipping_outlined,
                onTap: () => context.push('/register/driver')),
        ],
      ),
    ];
  }

  // Customer / Buyer: Quotations + Orders + full expand section
  return [
    _BuyerWelcomeBanner(),
    const SizedBox(height: AppSpacing.x2l),
    _HomeCard(
      icon: Icons.request_quote_outlined,
      iconBg: AppColors.primaryLight,
      iconColor: AppColors.primaryMain,
      title: 'Quotations',
      subtitle: 'Request prices from nurseries',
      onTap: () => tabs.state = 1,
    ),
    const SizedBox(height: AppSpacing.md),
    _HomeCard(
      icon: Icons.receipt_long_outlined,
      iconBg: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF2E7D32),
      title: 'Orders',
      subtitle: 'Track your active and past orders',
      onTap: () => tabs.state = 2,
    ),
    const SizedBox(height: AppSpacing.x2l),
    const Text('Expand Your Access', style: AppTypography.h3),
    const SizedBox(height: AppSpacing.sm),
    _ActionTile(
      icon: Icons.storefront_outlined,
      title: 'Register Your Nursery',
      subtitle: 'Join GreenRoot as a nursery owner',
      onTap: () => context.push('/register/nursery'),
    ),
    _ActionTile(
      icon: Icons.manage_accounts_outlined,
      title: 'Join as Manager',
      subtitle: 'Accept a manager invite from a nursery',
      onTap: () => context.push('/invite/accept'),
    ),
    _ActionTile(
      icon: Icons.local_shipping_outlined,
      title: 'Register as Driver',
      subtitle: 'Apply to become a delivery driver',
      onTap: () => context.push('/register/driver'),
    ),
    _ActionTile(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Accept an Invite',
      subtitle: 'Use an invite code or QR to join',
      onTap: () => context.push('/invite/accept'),
    ),
  ];
}

// ── Metric card (owner dashboard) ─────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    Text('$value',
                        style: AppTypography.h3.copyWith(height: 1.2)),
                    Text(sub,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Connections bar (compact summary) ─────────────────────────────────────────

class _ConnectionsBar extends StatelessWidget {
  final int managers;
  final int drivers;
  final int customers;
  final VoidCallback onTap;

  const _ConnectionsBar({
    required this.managers,
    required this.drivers,
    required this.customers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _ConnTile(
                icon: Icons.manage_accounts_rounded,
                iconColor: AppColors.teal700,
                iconBg: AppColors.teal100,
                label: 'Managers',
                count: managers,
                action: 'Invite',
              ),
              const _VDiv(),
              _ConnTile(
                icon: Icons.local_shipping_rounded,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                label: 'Drivers',
                count: drivers,
                action: 'Link',
              ),
              const _VDiv(),
              _ConnTile(
                icon: Icons.people_alt_rounded,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue100,
                label: 'Customers',
                count: customers,
                action: 'View',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VDiv extends StatelessWidget {
  const _VDiv();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 60, child: VerticalDivider(width: 1, color: AppColors.border));
}

class _ConnTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final int count;
  final String action;

  const _ConnTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.count,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 4),
            Text('$count',
                style: AppTypography.h4.copyWith(height: 1.1)),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(action,
                style: AppTypography.caption.copyWith(
                    color: iconColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Quick chip button ──────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primaryMain),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.h4),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyerWelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                color: AppColors.primaryMain, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You\'re signed in as a Customer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryMain,
                      fontFamily: 'Inter',
                    )),
                SizedBox(height: 2),
                Text(
                  'Browse nurseries, request quotations, and place orders.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryMain,
                    fontFamily: 'Inter',
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.forest100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryMain, size: 20),
        ),
        title: Text(title, style: AppTypography.label),
        subtitle: Text(
          subtitle,
          style:
              AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
    );
  }
}
