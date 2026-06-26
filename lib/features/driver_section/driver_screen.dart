import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../auth/presentation/providers/session_provider.dart';

class DriverScreen extends ConsumerWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (!caps.hasDriverProfile) {
      return const _NoDriverProfileScreen();
    }

    return const _DriverDashboardScreen();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// No driver profile — register CTA
// ──────────────────────────────────────────────────────────────────────────────

class _NoDriverProfileScreen extends StatelessWidget {
  const _NoDriverProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Driver', style: AppTypography.h3),
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
                Icons.local_shipping_outlined,
                size: 40,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text(
              'Become a Delivery Driver',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Register as a driver to start accepting delivery trips from nurseries.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x3l),
            AppButton(
              label: 'Register as Driver',
              onPressed: () => context.push('/register/driver'),
              trailingIcon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push('/invite/accept'),
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('Join a Trip with Invite Code'),
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
// Driver dashboard (has profile)
// ──────────────────────────────────────────────────────────────────────────────

class _DriverDashboardScreen extends StatelessWidget {
  const _DriverDashboardScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Driver', style: AppTypography.h3),
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
          // Active trip banner placeholder
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
                const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 30),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Active Trip',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Accept a trip invite to get started',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/invite/accept'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Join Trip'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('My Activity', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.route_outlined,
                label: 'My Trips',
                subtitle: 'View all past and current deliveries',
                onTap: () => context.push('/dispatches'),
              ),
              _MenuItem(
                icon: Icons.qr_code_rounded,
                label: 'Join a Trip',
                subtitle: 'Use an invite code to join a dispatch',
                onTap: () => context.push('/invite/accept'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Vehicle & Documents', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          _MenuSection(
            items: [
              _MenuItem(
                icon: Icons.badge_outlined,
                label: 'Driving Licence',
                subtitle: 'Upload or update your licence',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.directions_car_outlined,
                label: 'Vehicle Details',
                subtitle: 'Manage your vehicle information',
                onTap: () {},
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
// Shared menu components
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
