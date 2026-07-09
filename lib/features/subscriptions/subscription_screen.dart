import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../auth/data/models/capabilities_model.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'subscription_datasource.dart';
import 'subscription_models.dart';
import 'subscription_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Subscription', style: AppTypography.h3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(context, ref, caps),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, UserCapabilities caps) {
    // Driver only (no sell/buy workspace) → free
    if (caps.isDriverOnly) return const _FreeView(role: _FreeRole.driver);

    // Pure buyer (no canSell, no pending/rejected nursery) → free
    if (!caps.canSell && !caps.hasPendingNursery && !caps.hasRejectedNursery) {
      return const _FreeView(role: _FreeRole.buyer);
    }

    // Manager (not an owner) → managed workspace view
    if (caps.isManager && !caps.isNurseryOwner) {
      return _ManagerView(caps: caps);
    }

    // Owner (or pending/rejected) → full subscription screen
    final subAsync = ref.watch(subscriptionProvider);
    return subAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBody(
        message: e is AppError ? e.message : e.toString(),
        onRetry: () => ref.invalidate(subscriptionProvider),
      ),
      data: (sub) => sub == null
          ? _NoSubscription(onRefresh: () => ref.invalidate(subscriptionProvider))
          : _SubscriptionBody(sub: sub, onRefresh: () => ref.invalidate(subscriptionProvider)),
    );
  }
}

// ── Free access view (drivers & buyers) ──────────────────────────────────────

enum _FreeRole { driver, buyer }

class _FreeView extends StatelessWidget {
  final _FreeRole role;
  const _FreeView({required this.role});

  @override
  Widget build(BuildContext context) {
    final isDriver = role == _FreeRole.driver;
    final features = isDriver
        ? const [
            (Icons.local_shipping_outlined, 'Accept & manage deliveries'),
            (Icons.qr_code_scanner_rounded, 'Scan & confirm pickups'),
            (Icons.route_outlined, 'Real-time trip tracking'),
            (Icons.payments_outlined, 'Earnings per delivery'),
            (Icons.history_rounded, 'Full delivery history'),
          ]
        : const [
            (Icons.storefront_outlined, 'Browse nurseries & plants'),
            (Icons.shopping_cart_outlined, 'Place and track orders'),
            (Icons.request_quote_outlined, 'Request quotes from nurseries'),
            (Icons.local_shipping_outlined, 'Track deliveries in real time'),
            (Icons.favorite_border_rounded, 'Save favourites'),
          ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryMain.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                isDriver ? 'Driver Access is Free' : 'Marketplace is Free',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isDriver
                    ? 'Your GreenRoot delivery partner account has no subscription fees — ever.'
                    : 'Buying on GreenRoot is completely free. No subscription, no hidden charges.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // What's included
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("What's Included — Free", style: AppTypography.h4),
              const SizedBox(height: 14),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.forest100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(f.$1,
                              size: 17, color: AppColors.primaryMain),
                        ),
                        const SizedBox(width: 12),
                        Text(f.$2, style: AppTypography.body),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Reassurance note
        _Card(
          child: Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 18, color: AppColors.primaryMain),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDriver
                      ? 'GreenRoot will never charge drivers a subscription fee.'
                      : 'GreenRoot will never charge buyers to browse or purchase.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

// ── Manager workspace view ────────────────────────────────────────────────────

class _ManagerView extends StatelessWidget {
  final UserCapabilities caps;
  const _ManagerView({required this.caps});

  @override
  Widget build(BuildContext context) {
    final nurseries = caps.managedNurseries;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Header card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.manage_accounts_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Manager Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Managed via nursery plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your access is provided through the nursery subscription. Contact your nursery owner for billing details.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Managed nurseries
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Workspace${nurseries.length > 1 ? 's' : ''}',
                  style: AppTypography.h4),
              const SizedBox(height: 12),
              ...nurseries.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              size: 20, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.nurseryName ?? 'Nursery',
                                style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Subscription active',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.primaryMain,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppColors.primaryMain),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // What's included for managers
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Your Access Includes", style: AppTypography.h4),
              const SizedBox(height: 14),
              ...[
                (Icons.receipt_long_outlined, 'Order Management'),
                (Icons.request_quote_outlined, 'Quotations'),
                (Icons.local_shipping_outlined, 'Dispatch & Delivery'),
                (Icons.inventory_2_outlined, 'Inventory Management'),
                (Icons.people_outline_rounded, 'Team Coordination'),
                (Icons.storefront_outlined, 'Market Listings'),
              ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.forest100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(f.$1,
                              size: 17, color: AppColors.primaryMain),
                        ),
                        const SizedBox(width: 12),
                        Text(f.$2, style: AppTypography.body),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Billing info note
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Billing and plan management is handled by your nursery owner. For subscription renewals or upgrades, contact them directly.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

// ── No subscription state ─────────────────────────────────────────────────────

class _NoSubscription extends StatelessWidget {
  final VoidCallback onRefresh;
  const _NoSubscription({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: const Icon(Icons.workspace_premium_rounded,
                  size: 40, color: AppColors.primaryMain),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text('No Subscription', style: AppTypography.h2,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You don\'t have an active subscription yet. Contact support or wait for your nursery to be approved.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2l),
            AppButton(
              label: 'Refresh',
              onPressed: onRefresh,
              trailingIcon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _SubscriptionBody extends ConsumerStatefulWidget {
  final SubscriptionModel sub;
  final VoidCallback onRefresh;
  const _SubscriptionBody({required this.sub, required this.onRefresh});

  @override
  ConsumerState<_SubscriptionBody> createState() => _SubscriptionBodyState();
}

class _SubscriptionBodyState extends ConsumerState<_SubscriptionBody> {
  bool _cancelling = false;
  bool _paymentsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    final showCta = sub.isExpired ||
        sub.isTrial ||
        (sub.isActive && (sub.daysRemaining ?? 999) <= 30);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Hero card ──────────────────────────────────────────────────────
        _HeroCard(sub: sub),
        const SizedBox(height: AppSpacing.lg),

        // ── Plan details ───────────────────────────────────────────────────
        _PlanCard(sub: sub),
        const SizedBox(height: AppSpacing.lg),

        // ── What's included ────────────────────────────────────────────────
        _IncludedCard(isTrial: sub.isTrial),
        const SizedBox(height: AppSpacing.lg),

        // ── CTA ───────────────────────────────────────────────────────────
        if (showCta && !sub.isCancelled) ...[
          AppButton(
            label: sub.isExpired
                ? 'Renew Subscription'
                : sub.isTrial
                    ? 'Upgrade to Standard'
                    : 'Renew Now',
            onPressed: () => context.push('/subscription/payment?subId=${sub.id}'),
            trailingIcon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Payment history ────────────────────────────────────────────────
        _PaymentHistorySection(
          subscriptionId: sub.id,
          expanded: _paymentsExpanded,
          onToggle: () =>
              setState(() => _paymentsExpanded = !_paymentsExpanded),
        ),
        const SizedBox(height: AppSpacing.x2l),

        // ── Cancel ────────────────────────────────────────────────────────
        if (!sub.isCancelled && !sub.isExpired)
          Center(
            child: TextButton(
              onPressed: _cancelling ? null : () => _confirmCancel(context),
              child: _cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Cancel Subscription',
                      style: AppTypography.body.copyWith(
                        color: AppColors.red600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
            'Your access will end immediately. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final ds = SubscriptionRemoteDataSource(ApiClient.instance);
      await ds.cancelSubscription(widget.sub.id, null);
      if (mounted) {
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription cancelled.')),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final SubscriptionModel sub;
  const _HeroCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final days = sub.daysRemaining ?? 0;
    final fmt = DateFormat('d MMM yyyy');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryMain.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(sub.planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              _StatusBadge(status: sub.status),
            ],
          ),
          const SizedBox(height: 20),
          // Days remaining
          sub.isExpired
              ? const Text('Expired',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        )),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('days left',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          // Date range
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.white60, size: 14),
              const SizedBox(width: 6),
              Text(
                '${fmt.format(sub.startDate)} → ${sub.endDate != null ? fmt.format(sub.endDate!) : 'Ongoing'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'ACTIVE' => (const Color(0xFF43A047), Colors.white),
      'EXPIRED' => (AppColors.red600, Colors.white),
      'PAUSED' => (AppColors.amber600, Colors.white),
      _ => (Colors.white24, Colors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionModel sub;
  const _PlanCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sub.isTrial
                    ? const Color(0xFFFFF8E1)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                sub.planCode,
                style: TextStyle(
                  color: sub.isTrial
                      ? AppColors.amber600
                      : AppColors.primaryMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            if (sub.isTrial)
              const Text('₹0 / 6 months',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ))
            else
              const Text('₹499 / month',
                  style: TextStyle(
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
          ]),
          const SizedBox(height: 12),
          Text(sub.planName, style: AppTypography.h4),
          const SizedBox(height: 4),
          Text(
            sub.isTrial
                ? '6-month free trial — full platform access at no cost.'
                : 'Full platform access — manage orders, quotations, market listings, and more.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text('Code: ${sub.subscriptionCode}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── What's included card ──────────────────────────────────────────────────────

class _IncludedCard extends StatelessWidget {
  final bool isTrial;
  const _IncludedCard({required this.isTrial});

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.receipt_long_outlined, 'Order Management'),
      (Icons.request_quote_outlined, 'Quotations'),
      (Icons.local_shipping_outlined, 'Dispatch & Delivery'),
      (Icons.storefront_outlined, 'Market Listings'),
      (Icons.inventory_2_outlined, 'Inventory'),
      (Icons.people_outline_rounded, 'Team & Connections'),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's Included",
              style: AppTypography.h4),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features
                .map((f) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.$1,
                            size: 14, color: AppColors.primaryMain),
                        const SizedBox(width: 5),
                        Text(f.$2,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ))
                .toList(),
          ),
          if (isTrial) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 15, color: AppColors.amber600),
                const SizedBox(width: 6),
                Text(
                  'Upgrade to Standard for unlimited access after trial.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.amber600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payment history ───────────────────────────────────────────────────────────

class _PaymentHistorySection extends ConsumerWidget {
  final int subscriptionId;
  final bool expanded;
  final VoidCallback onToggle;

  const _PaymentHistorySection({
    required this.subscriptionId,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(
            children: [
              Text('Payment History', style: AppTypography.h4),
              const Spacer(),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          ref.watch(subscriptionPaymentsProvider(subscriptionId)).when(
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator())),
                error: (_, __) => Text('Failed to load payments',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                data: (payments) => payments.isEmpty
                    ? _Card(
                        child: Text('No payments recorded.',
                            style: AppTypography.body
                                .copyWith(color: AppColors.textSecondary)))
                    : _Card(
                        child: Column(
                          children: payments
                              .take(5)
                              .map((p) => _PaymentRow(payment: p))
                              .toList(),
                        ),
                      ),
              ),
        ],
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final SubscriptionPayment payment;
  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = payment.status == 'SUCCESS'
        ? (const Color(0xFFE8F5E9), const Color(0xFF2E7D32))
        : (AppColors.amber100, AppColors.amber600);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.paymentCode ?? '—',
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(payment.paymentMethod,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${payment.amount.toStringAsFixed(2)}',
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.w700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(payment.status,
                    style: AppTypography.caption.copyWith(
                        color: fg, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.red600),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.x2l),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

// ── Shared card container ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}
