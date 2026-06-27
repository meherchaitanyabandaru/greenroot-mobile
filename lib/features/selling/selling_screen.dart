import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../auth/data/models/capabilities_model.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../quotations/quotation_create_screen.dart';

class SellingScreen extends ConsumerWidget {
  const SellingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (!caps.canSell) {
      return const _NoAccessScreen();
    }

    if (caps.isNurseryOwner) {
      return _OwnerSellingScreen(caps: caps);
    }

    return _ManagerSellingScreen(caps: caps);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// No access gate
// ──────────────────────────────────────────────────────────────────────────────

class _NoAccessScreen extends StatelessWidget {
  const _NoAccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Selling', style: AppTypography.h3),
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
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 40,
                color: AppColors.primaryMain,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text(
              'Start Selling on GreenRoot',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Register your nursery or join as a manager to access selling features.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x3l),
            AppButton(
              label: 'Register Your Nursery',
              onPressed: () => context.push('/register/nursery'),
              trailingIcon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push('/invite/accept'),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Join as Manager'),
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size(double.infinity, AppSpacing.buttonHeight),
                side: const BorderSide(color: AppColors.primaryMain),
                foregroundColor: AppColors.primaryMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Owner selling menu
// ──────────────────────────────────────────────────────────────────────────────

class _OwnerSellingScreen extends StatelessWidget {
  final UserCapabilities caps;

  const _OwnerSellingScreen({required this.caps});

  @override
  Widget build(BuildContext context) {
    final nurseryId = caps.ownedNurseryId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caps.ownedNurseryName ?? 'My Nursery',
              style: AppTypography.h3,
            ),
            const Text(
              'Nursery Owner',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryMain,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.sm),
          const Text('Operations', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.request_quote_outlined,
                label: 'Quotations',
                subtitle: 'View and manage customer quotations',
                onTap: () => context.push('/quotations'),
              ),
              _MenuItem(
                icon: Icons.shopping_cart_outlined,
                label: 'Orders',
                subtitle: 'All confirmed orders for this nursery',
                onTap: () => context.push(nurseryId != null
                    ? '/orders?nursery=$nurseryId'
                    : '/orders'),
              ),
              _MenuItem(
                icon: Icons.local_shipping_outlined,
                label: 'Dispatches',
                subtitle: 'Track and manage all deliveries',
                onTap: () => context.push('/dispatches'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Inventory & Requests', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                subtitle: 'Manage plants and stock levels',
                onTap: () => context.push('/inventory/add'),
              ),
              _MenuItem(
                icon: Icons.eco_outlined,
                label: 'Plant Requests',
                subtitle: 'Review incoming plant requests',
                onTap: () => context.push('/requests/create'),
              ),
              _MenuItem(
                icon: Icons.travel_explore_outlined,
                label: 'Plant Sourcing Network',
                subtitle: 'Find nearby nurseries and open sourcing posts',
                onTap: () => context.push('/sourcing'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Team & Customers', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Managers',
                subtitle: 'Invite and manage Gumastha',
                onTap: () {
                  final id = nurseryId ?? 0;
                  final name = Uri.encodeComponent(
                      caps.ownedNurseryName ?? 'My Nursery');
                  context.push('/nursery/members?id=$id&name=$name&tab=0');
                },
              ),
              _MenuItem(
                icon: Icons.people_outline_rounded,
                label: 'Customers',
                subtitle: 'Invite and manage customers',
                onTap: () {
                  final id = nurseryId ?? 0;
                  final name = Uri.encodeComponent(
                      caps.ownedNurseryName ?? 'My Nursery');
                  context.push('/nursery/members?id=$id&name=$name&tab=1');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final choice = await showQuotationTypeDialog(context);
          if (choice == null || !context.mounted) return;

          if (choice == QuotationTypeChoice.directOrder) {
            context.push('/orders/create');
            return;
          }

          final type =
              choice == QuotationTypeChoice.internal ? 'INTERNAL' : 'CUSTOMER';
          context.push('/quotations/create?type=$type');
        },
        backgroundColor: AppColors.primaryMain,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Manager selling menu
// ──────────────────────────────────────────────────────────────────────────────

class _ManagerSellingScreen extends StatelessWidget {
  final UserCapabilities caps;

  const _ManagerSellingScreen({required this.caps});

  @override
  Widget build(BuildContext context) {
    final nurseryId = caps.primaryNurseryId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caps.primaryNurseryName ?? 'My Nursery',
              style: AppTypography.h3,
            ),
            const Text(
              'Manager / Gumastha',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.amber700,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.sm),
          // Loading queue priority banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_outlined,
                    color: Colors.white, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loading Queue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Start, complete, and hand over loaded orders',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(nurseryId != null
                      ? '/orders/loading?nursery=$nurseryId'
                      : '/orders/loading'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('My Work', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.request_quote_outlined,
                label: 'My Quotations',
                subtitle: 'Quotations assigned to me',
                onTap: () => context.push('/quotations'),
              ),
              _MenuItem(
                icon: Icons.shopping_cart_outlined,
                label: 'My Orders',
                subtitle: 'Active and pending orders',
                onTap: () => context.push(nurseryId != null
                    ? '/orders?nursery=$nurseryId'
                    : '/orders'),
              ),
              _MenuItem(
                icon: Icons.local_shipping_outlined,
                label: 'Dispatches',
                subtitle: 'Track and manage deliveries',
                onTap: () => context.push('/dispatches'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Requests', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.eco_outlined,
                label: 'Plant Requests',
                subtitle: 'View and respond to plant requests',
                onTap: () => context.push('/requests/create'),
              ),
              _MenuItem(
                icon: Icons.travel_explore_outlined,
                label: 'Plant Sourcing Network',
                subtitle: 'Find nearby nurseries and open sourcing posts',
                onTap: () => context.push('/sourcing'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared components
// ──────────────────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.forest100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryMain, size: 20),
      ),
      title: Text(label, style: AppTypography.label),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
