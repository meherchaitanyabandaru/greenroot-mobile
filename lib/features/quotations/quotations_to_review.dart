import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utilities/money.dart';
import 'quotations.dart';

/// Quotations other nurseries sent this user that wait for Accept or Decline.
Future<List<Quotation>> loadQuotationsToReview(QuotationRepository repo) async {
  try {
    final (items, _) = await repo.listBuyingQuotations(page: 1, perPage: 20);
    return items.where((q) => q.capabilities?.canAccept ?? false).toList();
  } catch (_) {
    return const [];
  }
}

/// Home card: one row per quotation waiting for the buyer, opening it.
class QuotationsToReviewCard extends StatelessWidget {
  final List<Quotation> quotations;
  const QuotationsToReviewCard({super.key, required this.quotations});

  @override
  Widget build(BuildContext context) {
    final n = quotations.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.amber600.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n == 1 ? 'A quotation to review' : '$n quotations to review',
            style: AppTypography.h3,
          ),
          const SizedBox(height: 4),
          Text(
            'Accept or decline it. Nothing is ordered until you accept.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          for (final q in quotations.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined,
                  color: AppColors.amber600,),
              title: Text(q.nurseryName ?? q.quotationCode),
              subtitle: Text('${q.quotationCode} · ${inr(q.totalAmount)}'),
              trailing: const Text(
                'Review',
                style: TextStyle(
                  color: AppColors.primaryMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => context.push('/quotations/${q.id}'),
            ),
        ],
      ),
    );
  }
}
