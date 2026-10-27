// Paid plans are Silver / Gold / Platinum (codes BASIC / GROWTH /
// ENTERPRISE); the trial and the free plan have no tier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/features/subscriptions/plan_tier.dart';

void main() {
  test('plan codes map to tiers', () {
    expect(PlanTier.fromCode('BASIC'), PlanTier.silver);
    expect(PlanTier.fromCode('GROWTH'), PlanTier.gold);
    expect(PlanTier.fromCode('ENTERPRISE'), PlanTier.platinum);
    for (final none in ['TRIAL', 'FREE', null, '']) {
      expect(PlanTier.fromCode(none), isNull);
    }
  });

  testWidgets('the badge names the tier', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TierBadge(tier: PlanTier.gold))));
    expect(find.text('Gold member'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });
}
