import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero app bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B5E20),
                      AppColors.primaryMain,
                      Color(0xFF66BB6A),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'GreenRoot',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'India\'s Plant Nursery Network',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forest100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: AppColors.primaryMain,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),

                  // Mission
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.forest100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.flag_outlined,
                                color: AppColors.primaryMain,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Text(
                              'Our Mission',
                              style: AppTypography.h4,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'GreenRoot connects nursery owners, buyers, and logistics partners '
                          'on a single platform — making plant trade transparent, '
                          'efficient, and accessible across India.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // What we do
                  const Text(
                    'What GreenRoot Does',
                    style: AppTypography.h4,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeatureTile(
                    icon: Icons.storefront_outlined,
                    iconColor: AppColors.primaryMain,
                    iconBg: AppColors.forest100,
                    title: 'Nursery Network',
                    body:
                        'Verified nurseries list their inventory and connect directly '
                        'with buyers — no middlemen, no guesswork.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeatureTile(
                    icon: Icons.request_quote_outlined,
                    iconColor: AppColors.blue600,
                    iconBg: Color(0xFFE3F2FD),
                    title: 'Quotations & Orders',
                    body:
                        'Nurseries send price quotations, buyers review and accept, '
                        'and orders are created — all within the app.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeatureTile(
                    icon: Icons.local_shipping_outlined,
                    iconColor: Color(0xFF7B1FA2),
                    iconBg: Color(0xFFF3E5F5),
                    title: 'Live Delivery Tracking',
                    body:
                        'Drivers are assigned to dispatches. Buyers track their delivery '
                        'in real time from loading to doorstep.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeatureTile(
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.amber700,
                    iconBg: AppColors.amber100,
                    title: 'Inventory Management',
                    body:
                        'Nursery owners and managers maintain a live plant inventory '
                        'with sizes, pricing, and availability.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeatureTile(
                    icon: Icons.people_outline_rounded,
                    iconColor: Color(0xFF00897B),
                    iconBg: Color(0xFFE0F2F1),
                    title: 'Team Management',
                    body: 'Owners invite managers (Gumastha) to their nursery. '
                        'Managers handle day-to-day operations with full work access.',
                  ),
                  const SizedBox(height: AppSpacing.x2l),

                  // Who we serve
                  const Text('Who We Serve', style: AppTypography.h4),
                  const SizedBox(height: AppSpacing.sm),
                  _RoleGrid(),
                  const SizedBox(height: AppSpacing.x2l),

                  // Links
                  const Text('Links', style: AppTypography.h4),
                  const SizedBox(height: AppSpacing.sm),
                  _Card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _LinkTile(
                          icon: Icons.language_rounded,
                          label: 'Website',
                          value: 'www.greenroot.in',
                          onTap: () => _launch('https://www.greenroot.in'),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _LinkTile(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          value: 'greenroot.in/privacy',
                          onTap: () => context.push('/privacy-policy'),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _LinkTile(
                          icon: Icons.gavel_rounded,
                          label: 'Terms of Service',
                          value: 'greenroot.in/terms',
                          onTap: () => context.push('/terms-of-service'),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _LinkTile(
                          icon: Icons.email_outlined,
                          label: 'Contact',
                          value: 'hello@greenroot.in',
                          onTap: () => _launch('mailto:hello@greenroot.in'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.eco_rounded,
                          color: AppColors.primaryMain,
                          size: 28,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '© ${DateTime.now().year} GreenRoot Technologies Pvt. Ltd.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Made with ❤ in India',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Card wrapper ───────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// ── Feature tile ───────────────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;

  const _FeatureTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
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

// ── Role grid ──────────────────────────────────────────────────────────────────

class _RoleGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const roles = [
      (
        Icons.shopping_bag_outlined,
        'Buyers',
        'Purchase plants from verified nurseries',
        AppColors.primaryMain,
        AppColors.forest100
      ),
      (
        Icons.local_florist_rounded,
        'Nursery Owners',
        'Manage inventory, orders & team',
        Color(0xFF7B1FA2),
        Color(0xFFF3E5F5)
      ),
      (
        Icons.manage_accounts_rounded,
        'Managers',
        'Handle daily nursery operations',
        AppColors.amber700,
        AppColors.amber100
      ),
      (
        Icons.local_shipping_outlined,
        'Drivers',
        'Deliver plants with live tracking',
        AppColors.blue600,
        Color(0xFFE3F2FD)
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: roles
          .map(
            (r) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: r.$5,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(r.$1, color: r.$4, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.$2,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.$3,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Link tile ──────────────────────────────────────────────────────────────────

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryMain),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    value,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
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
    );
  }
}
