import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_provider.dart';

/// The paid plans as owners know them. Plan codes stay BASIC / GROWTH /
/// ENTERPRISE in the API; these are their names and colours.
enum PlanTier {
  silver('Silver', Color(0xFF94A3B8), Color(0xFFE2E8F0), Color(0xFF475569)),
  gold('Gold', Color(0xFFD4A017), Color(0xFFFDE68A), Color(0xFF854D0E)),
  platinum('Platinum', Color(0xFF6D5BD0), Color(0xFFDDD6FE), Color(0xFF3B2F8F));

  const PlanTier(this.label, this.dark, this.light, this.ink);
  final String label;
  final Color dark; // medal
  final Color light; // shine / background
  final Color ink; // text on light

  static PlanTier? fromCode(String? planCode) => switch (planCode) {
        'BASIC' => PlanTier.silver,
        'GROWTH' => PlanTier.gold,
        'ENTERPRISE' => PlanTier.platinum,
        _ => null,
      };

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, dark],
      );
}

/// The owner's paid tier while the subscription is active; null on the free
/// trial, without a plan, or for anyone who is not an owner.
final ownerTierProvider = Provider.autoDispose<PlanTier?>((ref) {
  final sub = ref.watch(subscriptionProvider).valueOrNull;
  if (sub == null || !sub.isActive) return null;
  return PlanTier.fromCode(sub.planCode);
});

/// A round medal in the tier's metal.
class TierMedal extends StatelessWidget {
  final PlanTier tier;
  final double size;
  const TierMedal({super.key, required this.tier, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: tier.gradient,
          boxShadow: [
            BoxShadow(
              color: tier.dark.withValues(alpha: 0.35),
              blurRadius: size / 5,
              offset: Offset(0, size / 14),
            ),
          ],
          border: Border.all(color: Colors.white, width: size / 18),
        ),
        child: Icon(
          Icons.workspace_premium_rounded,
          color: Colors.white,
          size: size * 0.58,
        ),
      );
}

/// "Gold member" pill shown next to an owner's name.
class TierBadge extends StatelessWidget {
  final PlanTier tier;
  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${tier.label} plan member',
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tier.light, tier.light.withValues(alpha: 0.5)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tier.dark.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TierMedal(tier: tier, size: 20),
              const SizedBox(width: 6),
              Text(
                '${tier.label} member',
                style: TextStyle(
                  color: tier.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
}
