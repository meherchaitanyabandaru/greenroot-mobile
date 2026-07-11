import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import 'subscription_models.dart';
import 'subscription_provider.dart';

class SubscriptionPaymentScreen extends ConsumerStatefulWidget {
  final int subscriptionId;
  const SubscriptionPaymentScreen({super.key, required this.subscriptionId});

  @override
  ConsumerState<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState
    extends ConsumerState<SubscriptionPaymentScreen> {
  String _billingCycle = 'SIX_MONTH';
  String _paymentMethod = 'UPI';
  bool _paying = false;

  final _promoController = TextEditingController();
  bool _validatingPromo = false;
  double? _promoSavings;
  String? _promoMessage;
  bool _promoValid = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  double _basePrice(SubscriptionPlan? plan) {
    if (plan == null) return 0;
    if (_billingCycle == 'YEARLY') return plan.yearlyPrice ?? 0;
    return plan.sixMonthPrice ?? 0;
  }

  double _total(SubscriptionPlan? plan) {
    final base = _basePrice(plan) - (_promoSavings ?? 0);
    return base.clamp(0, double.infinity);
  }

  Future<void> _applyPromo(SubscriptionPlan? plan) async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty || plan == null) return;
    setState(() {
      _validatingPromo = true;
      _promoMessage = null;
      _promoValid = false;
      _promoSavings = null;
    });
    try {
      final ds = ref.read(subscriptionDataSourceProvider);
      final result = await ds.validatePromo(
        promoCode: code,
        planCode: plan.planCode,
        billingCycle: _billingCycle,
      );
      final valid = result['valid'] as bool? ?? false;
      if (valid) {
        final savings = (result['savings'] as num?)?.toDouble() ?? 0;
        setState(() {
          _promoValid = true;
          _promoSavings = savings;
          _promoMessage =
              'Code applied! You save ₹${savings.toStringAsFixed(0)}';
        });
      } else {
        setState(() {
          _promoValid = false;
          _promoMessage = result['message'] as String? ?? 'Invalid promo code';
        });
      }
    } catch (_) {
      setState(() {
        _promoMessage = 'Could not validate promo code';
      });
    } finally {
      setState(() {
        _validatingPromo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Upgrade Plan', style: AppTypography.h3),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e is AppError ? e.message : e.toString())),
        data: (plans) {
          final plan = plans
              .where((p) => p.planCode == 'GROWTH' && p.isActive)
              .firstOrNull;
          return _PaymentBody(
            plan: plan,
            billingCycle: _billingCycle,
            paymentMethod: _paymentMethod,
            basePrice: _basePrice(plan),
            promoSavings: _promoSavings,
            total: _total(plan),
            paying: _paying,
            promoController: _promoController,
            promoValid: _promoValid,
            promoMessage: _promoMessage,
            validatingPromo: _validatingPromo,
            onCycleChanged: (v) => setState(() {
              _billingCycle = v;
              _promoValid = false;
              _promoSavings = null;
              _promoMessage = null;
            }),
            onMethodChanged: (v) => setState(() => _paymentMethod = v),
            onApplyPromo: () => _applyPromo(plan),
            onPay: _pay,
          );
        },
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    // DEV BYPASS: simulate payment and show success without gateway call.
    // Replace this block with real Razorpay SDK when integrating payments.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _paying = false);

    final now = DateTime.now();
    final endDate = _billingCycle == 'YEARLY'
        ? now.add(const Duration(days: 365))
        : now.add(const Duration(days: 180));
    final mockSub = SubscriptionModel(
      id: widget.subscriptionId,
      subscriptionCode: 'SUB-DEV-${DateTime.now().millisecondsSinceEpoch}',
      planCode: 'GROWTH',
      planName: '🚀 Growth',
      startDate: now,
      endDate: endDate,
      status: 'ACTIVE',
      autoRenew: true,
      daysRemaining: _billingCycle == 'YEARLY' ? 365 : 180,
    );
    ref.invalidate(subscriptionProvider);
    _showSuccess(mockSub);
  }

  void _showSuccess(SubscriptionModel sub) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SuccessSheet(
        sub: sub,
        onDone: () {
          Navigator.pop(ctx);
          context.pop();
        },
      ),
    );
  }
}

// ── Payment body ──────────────────────────────────────────────────────────────

class _PaymentBody extends StatelessWidget {
  final SubscriptionPlan? plan;
  final String billingCycle;
  final String paymentMethod;
  final double basePrice;
  final double? promoSavings;
  final double total;
  final bool paying;
  final TextEditingController promoController;
  final bool promoValid;
  final String? promoMessage;
  final bool validatingPromo;
  final ValueChanged<String> onCycleChanged;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onApplyPromo;
  final VoidCallback onPay;

  const _PaymentBody({
    required this.plan,
    required this.billingCycle,
    required this.paymentMethod,
    required this.basePrice,
    this.promoSavings,
    required this.total,
    required this.paying,
    required this.promoController,
    required this.promoValid,
    this.promoMessage,
    required this.validatingPromo,
    required this.onCycleChanged,
    required this.onMethodChanged,
    required this.onApplyPromo,
    required this.onPay,
  });

  String _formatPrice(double? value) {
    if (value == null || value == 0) return '₹0';
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return '₹${formatter.format(value.round())}';
  }

  @override
  Widget build(BuildContext context) {
    final sixDiscPct = plan?.sixMonthDiscountPct ?? 0;
    final yearDiscPct = plan?.yearlyDiscountPct ?? 0;
    final sixLabel = plan?.sixMonthPrice != null
        ? '${_formatPrice(plan!.sixMonthPrice)} / 6 months'
        : '...';
    final yearLabel = plan?.yearlyPrice != null
        ? '${_formatPrice(plan!.yearlyPrice)} / year'
        : '...';
    final sixMrpLabel = plan?.mrpSixMonthPrice != null
        ? _formatPrice(plan!.mrpSixMonthPrice)
        : null;
    final yearMrpLabel = plan?.mrpYearlyPrice != null
        ? _formatPrice(plan!.mrpYearlyPrice)
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Plan info ────────────────────────────────────────────────────────
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plan?.planCode ?? 'GROWTH',
                      style: const TextStyle(
                        color: AppColors.primaryMain,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(plan?.planName ?? 'Growth Plan', style: AppTypography.h3),
              const SizedBox(height: 4),
              Text(
                plan?.description ??
                    'Unlimited orders, quotations & up to 5 managers per nursery.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              if (plan?.features != null) ...[
                const SizedBox(height: 12),
                _FeatureChips(features: plan!.features!),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Billing cycle ────────────────────────────────────────────────────
        Text('Billing Cycle', style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _CycleChip(
              label: '6 Months',
              sublabel: sixLabel,
              mrpLabel: sixMrpLabel,
              badge: sixDiscPct > 0 ? '$sixDiscPct% OFF' : null,
              selected: billingCycle == 'SIX_MONTH',
              onTap: () => onCycleChanged('SIX_MONTH'),
            ),
            const SizedBox(width: 12),
            _CycleChip(
              label: 'Yearly',
              sublabel: yearLabel,
              mrpLabel: yearMrpLabel,
              badge: yearDiscPct > 0 ? '$yearDiscPct% OFF' : null,
              selected: billingCycle == 'YEARLY',
              onTap: () => onCycleChanged('YEARLY'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2l),

        // ── Payment method ───────────────────────────────────────────────────
        Text('Payment Method', style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final m in ['UPI', 'CARD', 'CASH'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m),
                  selected: paymentMethod == m,
                  onSelected: (_) => onMethodChanged(m),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: paymentMethod == m
                        ? AppColors.primaryMain
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2l),

        // ── Promo code ───────────────────────────────────────────────────────
        Text('Have a Promo Code?', style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: promoController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. DIWALI2026',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: promoValid
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.green)
                      : null,
                ),
                style: const TextStyle(
                    fontFamily: 'monospace', letterSpacing: 1.5, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: validatingPromo ? null : onApplyPromo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: validatingPromo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Apply',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        if (promoMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: promoValid
                  ? const Color(0xFFdcfce7)
                  : const Color(0xFFfee2e2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  promoValid
                      ? Icons.local_offer_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: promoValid
                      ? const Color(0xFF16a34a)
                      : const Color(0xFFdc2626),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    promoMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: promoValid
                          ? const Color(0xFF15803d)
                          : const Color(0xFFb91c1c),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x2l),

        // ── Price breakdown ──────────────────────────────────────────────────
        Text('Price Breakdown', style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          child: Column(
            children: [
              _PriceLine(
                  label: 'Base Price',
                  value: '₹${basePrice.toStringAsFixed(2)}'),
              if (promoSavings != null && promoSavings! > 0) ...[
                const SizedBox(height: 8),
                _PriceLine(
                  label: 'Promo Discount',
                  value: '−₹${promoSavings!.toStringAsFixed(2)}',
                  highlight: true,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.border, height: 1),
              ),
              _PriceLine(
                label: 'Total',
                value: '₹${total.toStringAsFixed(2)}',
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3l),

        // ── Pay button ───────────────────────────────────────────────────────
        AppButton(
          label: 'Pay ₹${total.toStringAsFixed(2)} Securely',
          onPressed: paying ? null : onPay,
          isLoading: paying,
          trailingIcon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Secured via Razorpay · Invoice provided',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

class _FeatureChips extends StatelessWidget {
  final Map<String, dynamic> features;
  const _FeatureChips({required this.features});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (features['unlimited_orders'] == true) chips.add('Unlimited Orders');
    if (features['unlimited_quotations'] == true)
      chips.add('Unlimited Quotations');
    final maxMgr = features['max_managers'];
    if (maxMgr != null) chips.add('Up to $maxMgr Managers');
    final support = features['support'];
    if (support != null) chips.add('${_cap(support.toString())} Support');

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips
          .map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c,
                  style: const TextStyle(
                    color: AppColors.primaryMain,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ))
          .toList(),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _CycleChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final String? mrpLabel;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _CycleChip({
    required this.label,
    required this.sublabel,
    this.mrpLabel,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryMain : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryMain
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      )),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFdc2626),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              if (mrpLabel != null)
                Text(
                  mrpLabel!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
              Text(sublabel,
                  style: AppTypography.caption.copyWith(
                    color: selected
                        ? AppColors.primaryMain
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool highlight;

  const _PriceLine({
    required this.label,
    required this.value,
    this.bold = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = highlight
        ? AppTypography.body.copyWith(
            color: const Color(0xFF16a34a), fontWeight: FontWeight.w700)
        : bold
            ? AppTypography.body
                .copyWith(fontWeight: FontWeight.w800, fontSize: 16)
            : AppTypography.body;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

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

// ── Success sheet ─────────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final SubscriptionModel sub;
  final VoidCallback onDone;
  const _SuccessSheet({required this.sub, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'en_IN');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryMain,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text('Payment Successful!',
                style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your ${sub.planName} subscription is now active.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2l),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _SuccessRow(label: 'Code', value: sub.subscriptionCode),
                  const SizedBox(height: 6),
                  _SuccessRow(label: 'Plan', value: sub.planName),
                  const SizedBox(height: 6),
                  if (sub.endDate != null)
                    _SuccessRow(
                        label: 'Valid Until', value: fmt.format(sub.endDate!)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            AppButton(
              label: 'Done',
              onPressed: onDone,
              trailingIcon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;
  const _SuccessRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: AppTypography.bodySmall
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      );
}
