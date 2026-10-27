import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'razorpay_checkout.dart';
import 'subscription_models.dart';
import 'subscription_provider.dart';
import '../../core/utilities/money.dart';
import '../../core/widgets/app_loader.dart';

class SubscriptionPaymentScreen extends ConsumerStatefulWidget {
  final int subscriptionId;
  const SubscriptionPaymentScreen({super.key, required this.subscriptionId});

  @override
  ConsumerState<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState
    extends ConsumerState<SubscriptionPaymentScreen> {
  String? _planCode; // null: the current paid plan, else Growth
  String _billingCycle = 'MONTHLY';
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

  /// Paid plans, cheapest first.
  List<SubscriptionPlan> _paidPlans(List<SubscriptionPlan> plans) =>
      plans.where((p) => p.isActive && p.isPaid).toList()
        ..sort((a, b) => (a.monthlyPrice ?? 0).compareTo(b.monthlyPrice ?? 0));

  SubscriptionPlan? _selected(List<SubscriptionPlan> paid) {
    final current = ref.read(subscriptionProvider).valueOrNull?.planCode;
    final code = _planCode ?? current;
    return paid.where((p) => p.planCode == code).firstOrNull ??
        paid.where((p) => p.planCode == 'GROWTH').firstOrNull ??
        paid.firstOrNull;
  }

  double _basePrice(SubscriptionPlan? plan) =>
      plan?.priceFor(_billingCycle)?.amount ?? 0;

  void _resetPromo() {
    _promoValid = false;
    _promoSavings = null;
    _promoMessage = null;
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
        loading: () => const Center(child: AppLoader()),
        error: (e, _) =>
            Center(child: Text(e is AppError ? e.message : e.toString())),
        data: (plans) {
          final paid = _paidPlans(plans);
          final plan = _selected(paid);
          return _PaymentBody(
            plans: paid,
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
            onPlanChanged: (code) => setState(() {
              _planCode = code;
              _resetPromo(); // a promo may apply to one plan only
            }),
            onCycleChanged: (v) => setState(() {
              _billingCycle = v;
              _resetPromo();
            }),
            onMethodChanged: (v) => setState(() => _paymentMethod = v),
            onApplyPromo: () => _applyPromo(plan),
            onPay: () => _pay(plan),
          );
        },
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.red600 : null,
        duration: Duration(seconds: error ? 8 : 4),
      ),
    );
  }

  Future<void> _pay(SubscriptionPlan? plan) async {
    if (plan == null) return;
    setState(() => _paying = true);
    final ds = ref.read(subscriptionDataSourceProvider);
    final promo = _promoValid ? _promoController.text.trim() : null;
    CheckoutResult? paid;
    try {
      // The API prices the order; null = online payments off (mock mode).
      final order = await ds.createPaymentOrder(
        subscriptionId: widget.subscriptionId,
        planId: plan.id,
        billingCycle: _billingCycle,
        promoCode: promo,
      );
      if (order != null) {
        paid = await payWithRazorpay(
          order,
          description: '${plan.planName} plan',
          contact: ref.read(sessionProvider).user?.mobile,
          method: _paymentMethod,
        );
      }
      final sub = widget.subscriptionId > 0
          ? await ds.renewSubscription(
              subscriptionId: widget.subscriptionId,
              planId: plan.id,
              billingCycle: _billingCycle,
              paymentMethod: _paymentMethod,
              paid: paid,
              promoCode: promo,
            )
          : await ds.createSubscription(
              planId: plan.id,
              billingCycle: _billingCycle,
              paymentMethod: _paymentMethod,
              paid: paid,
              promoCode: promo,
            );
      if (!mounted) return;
      ref.invalidate(subscriptionProvider);
      _showSuccess(sub);
    } on CheckoutCancelled {
      _snack('Payment cancelled. You have not been charged.');
    } on CheckoutFailed catch (e) {
      _snack(e.message, error: true);
    } on AppError catch (e) {
      // Money taken but not applied: give the user the id support needs.
      _snack(
        paid == null
            ? e.message
            : 'Payment ${paid.paymentId} received but not applied: ${e.message} '
                'Contact support with this payment ID.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showSuccess(SubscriptionModel sub) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      isScrollControlled: true, // taller than the default 9/16 on small phones

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
  final List<SubscriptionPlan> plans;
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
  final ValueChanged<String> onPlanChanged;
  final ValueChanged<String> onCycleChanged;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onApplyPromo;
  final VoidCallback onPay;

  const _PaymentBody({
    required this.plans,
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
    required this.onPlanChanged,
    required this.onCycleChanged,
    required this.onMethodChanged,
    required this.onApplyPromo,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final cycle = plan?.priceFor(billingCycle);
    final cycleSaving = cycle == null ? 0.0 : cycle.listAmount - cycle.amount;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Why pay ─────────────────────────────────────────────────────────
        const Text('Choose your plan', style: AppTypography.h2),
        const SizedBox(height: 4),
        Text(
          'Every plan has unlimited quotations, orders, customers and trips. '
          'Pick by the size of your team.',
          style:
              AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Plans ───────────────────────────────────────────────────────────
        if (plans.isEmpty)
          const _SectionCard(
            child: Text(
              'Plans are not available right now. Please try again later.',
            ),
          )
        else
          for (final p in plans) ...[
            _PlanCard(
              plan: p,
              cycle: p.priceFor(billingCycle),
              selected: p.planCode == plan?.planCode,
              popular: p.planCode == 'GROWTH',
              onTap: () => onPlanChanged(p.planCode),
            ),
            const SizedBox(height: 10),
          ],
        if (plan?.features != null) ...[
          const SizedBox(height: 4),
          _FeatureChips(features: plan!.features!),
        ],
        const SizedBox(height: AppSpacing.x2l),

        // ── Billing cycle ────────────────────────────────────────────────────
        const Text('Pay for', style: AppTypography.h4),
        const SizedBox(height: 2),
        Text(
          'Pay ahead and save up to 15%.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (plan != null)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              for (final c in plan!.cyclePrices)
                _CycleTile(
                  price: c,
                  selected: c.billingCycle == billingCycle,
                  onTap: () => onCycleChanged(c.billingCycle),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.x2l),

        // ── Payment method ───────────────────────────────────────────────────
        const Text('Payment Method', style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            // Online only: the chip opens checkout on that method (cash is an admin entry).
            for (final m in ['UPI', 'CARD'])
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
        const Text('Have a Promo Code?', style: AppTypography.h4),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: promoValid
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        )
                      : null,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: validatingPromo ? null : onApplyPromo,
                style: ElevatedButton.styleFrom(
                  // The app theme makes buttons full-width; in this Row that
                  // left no room, and the promo field never showed.
                  minimumSize: const Size(88, 46),
                  backgroundColor: AppColors.primaryMain,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: validatingPromo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
        const Text('Price Breakdown', style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          child: Column(
            children: [
              _PriceLine(
                label: cycle == null
                    ? 'Plan price'
                    : '${plan!.planName} × ${cycle.months} month${cycle.months == 1 ? '' : 's'}',
                value: inr(cycle?.listAmount ?? basePrice),
              ),
              if (cycle != null && cycleSaving > 0) ...[
                const SizedBox(height: 8),
                _PriceLine(
                  label: '${cycle.label} saving (${cycle.discountPercent}%)',
                  value: '−${inr(cycleSaving)}',
                  highlight: true,
                ),
              ],
              if (promoSavings != null && promoSavings! > 0) ...[
                const SizedBox(height: 8),
                _PriceLine(
                  label: 'Promo Discount',
                  value: '−${inr(promoSavings!)}',
                  highlight: true,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.border, height: 1),
              ),
              _PriceLine(
                label: 'Total',
                value: inr(total),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3l),

        // ── Pay button ───────────────────────────────────────────────────────
        AppButton(
          label: 'Pay ${inr(total)} Securely',
          onPressed: paying ? null : onPay,
          isLoading: paying,
          trailingIcon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.security_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Secured via Razorpay · Invoice provided',
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
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
    final chips = <String>[
      if (features['unlimited_quotations'] == true) 'Unlimited quotations',
      if (features['unlimited_orders'] == true) 'Unlimited orders',
      if (features['unlimited_customers'] == true) 'Unlimited customers',
      if (features['unlimited_trips'] == true) 'Unlimited trips',
      if (features['support'] != null)
        '${_cap(features['support'].toString())} support',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: AppColors.primaryMain,
                ),
                const SizedBox(width: 3),
                Text(
                  c,
                  style: const TextStyle(
                    color: AppColors.primaryMain,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// A plan to pick: team size and its price per month for the chosen cycle.
class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final CyclePrice? cycle;
  final bool selected;
  final bool popular;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.selected,
    required this.popular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final perMonth = cycle?.perMonth ?? plan.monthlyPrice ?? 0;
    final discounted = cycle != null && cycle!.discountPercent > 0;
    return Semantics(
      selected: selected,
      button: true,
      label: '${plan.planName}, ${inr(perMonth, paise: false)} a month',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryMain : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primaryMain : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(plan.planName, style: AppTypography.h4),
                        if (popular)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber600,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'MOST POPULAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.maxManagers == null
                          ? 'Unlimited managers'
                          : 'Up to ${plan.maxManagers} managers',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discounted)
                    Text(
                      inr(plan.monthlyPrice ?? 0, paise: false),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: inr(perMonth, paise: false),
                          style: AppTypography.h3.copyWith(
                            color: selected
                                ? AppColors.primaryMain
                                : AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '/mo',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How long to pay for: the total, its monthly cost and the saving.
class _CycleTile extends StatelessWidget {
  final CyclePrice price;
  final bool selected;
  final VoidCallback onTap;

  const _CycleTile({
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    price.label,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primaryMain
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (price.discountPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16a34a),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SAVE ${price.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                inr(price.amount),
                style: AppTypography.bodySmall
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                price.months == 1
                    ? 'billed monthly'
                    : '${inr(price.perMonth, paise: false)}/mo',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
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
            color: const Color(0xFF16a34a),
            fontWeight: FontWeight.w700,
          )
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
    // No locale: date symbols for 'en_IN' are never loaded, so it throws.
    final fmt = DateFormat('d MMM yyyy');

    return SafeArea(
      child: SingleChildScrollView(
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
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text(
              'Payment Successful!',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              sub.startDate.isAfter(DateTime.now())
                  ? 'Your ${sub.planName} plan is paid. It starts when your current period ends.'
                  : 'Your ${sub.planName} subscription is now active.',
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
                  // Renewals stack: a paid period can start after the trial
                  // or the current period ends.
                  if (sub.startDate.isAfter(DateTime.now())) ...[
                    _SuccessRow(
                      label: 'Starts',
                      value: fmt.format(sub.startDate),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (sub.endDate != null)
                    _SuccessRow(
                      label: 'Valid Until',
                      value: fmt.format(sub.endDate!),
                    ),
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
          Text(
            label,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style:
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      );
}
