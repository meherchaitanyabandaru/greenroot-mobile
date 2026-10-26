import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Which tour a user sees: one per role, in plain words.
enum TourRole { owner, manager, customer, driver }

typedef _Card = ({IconData icon, String title, String body});

const _cards = <TourRole, List<_Card>>{
  TourRole.owner: [
    (
      icon: Icons.request_quote_rounded,
      title: 'Quote, then order',
      body: 'Tap New Quotation and send it to your customer. When they '
          'accept, tap Convert to Order.',
    ),
    (
      icon: Icons.local_shipping_rounded,
      title: 'Load and send',
      body: 'On the order, follow the glowing button: Confirm, Start Loading, '
          'Complete Loading, then Create Dispatch and show the trip QR to '
          'your driver.',
    ),
    (
      icon: Icons.group_add_rounded,
      title: 'Your team',
      body: 'Invite Member adds managers, customers and drivers. Your '
          'subscription covers your managers too.',
    ),
  ],
  TourRole.manager: [
    (
      icon: Icons.work_rounded,
      title: 'Your work',
      body: 'The Work tab lists the quotations and orders your owner gives '
          'you. Send quotations and convert accepted ones to orders.',
    ),
    (
      icon: Icons.local_shipping_rounded,
      title: 'Load and send',
      body: 'On an order, follow the glowing button: Confirm, Start Loading, '
          'Complete Loading, then Create Dispatch.',
    ),
    (
      icon: Icons.info_outline_rounded,
      title: 'If you are blocked',
      body: "You work under your owner's plan. If creating fails, ask the "
          'owner to renew it in Profile → Subscription.',
    ),
  ],
  TourRole.customer: [
    (
      icon: Icons.request_quote_rounded,
      title: 'Quotations come to you',
      body: 'Nurseries send you quotations. Open Buying → Quotations and tap '
          'Accept or Decline.',
    ),
    (
      icon: Icons.location_on_rounded,
      title: 'Add your address',
      body: 'Add a delivery address before accepting, so the nursery can '
          'deliver.',
    ),
    (
      icon: Icons.local_shipping_rounded,
      title: 'Follow your order',
      body: 'Buying → Orders and Deliveries show where your plants are. To '
          'join a nursery, scan its invite QR from Home.',
    ),
  ],
  TourRole.driver: [
    (
      icon: Icons.qr_code_scanner_rounded,
      title: 'Join a trip',
      body: 'Tap Scan and scan the trip QR the nursery shows you (or paste the '
          'trip code they send), then tap Accept Trip.',
    ),
    (
      icon: Icons.route_rounded,
      title: 'Drive',
      body: 'When the nursery marks it dispatched, tap Start Journey. Use Add '
          'Event for delays or checkpoints on the way.',
    ),
    (
      icon: Icons.photo_camera_rounded,
      title: 'Deliver',
      body: 'At the customer, tap Upload Proof and take a photo, then Complete '
          'Delivery.',
    ),
  ],
};

String _seenKey(TourRole r) => 'welcome_tour_seen_${r.name}';

/// Shows the tour once per role on this device; [force] shows it again
/// (Profile → How GreenRoot works). Returns whether it was shown.
Future<bool> showWelcomeTour(BuildContext context, TourRole role,
    {bool force = false,}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(_seenKey(role)) ?? false)) return false;
    await prefs.setBool(_seenKey(role), true);
  } catch (_) {
    if (!force) return false; // no storage: don't risk showing it every launch
  }
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TourSheet(cards: _cards[role]!),
  );
  return true;
}

class _TourSheet extends StatefulWidget {
  final List<_Card> cards;
  const _TourSheet({required this.cards});

  @override
  State<_TourSheet> createState() => _TourSheetState();
}

class _TourSheetState extends State<_TourSheet> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == widget.cards.length - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How GreenRoot works', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 220,
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final c in widget.cards)
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.forest100,
                          child: Icon(c.icon,
                              size: 36, color: AppColors.primaryMain,),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(c.title,
                            style: AppTypography.h4,
                            textAlign: TextAlign.center,),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          c.body,
                          textAlign: TextAlign.center,
                          style: AppTypography.body
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.cards.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.primaryMain
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Need help later? Tap 🥭 Ask Mango — drag it anywhere you like.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => last
                    ? Navigator.of(context).pop()
                    : _page.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                child: Text(last ? 'Got it' : 'Next'),
              ),
            ),
            if (!last)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip'),
              ),
          ],
        ),
      ),
    );
  }
}
