// Invites waiting for this person's mobile number (GET /invites/mine): an
// owner often invites someone before they have the app, and they then sign
// in without the code. Shows nothing when there are none.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'invite_accept_screen.dart';

final pendingInvitesProvider =
    FutureProvider.autoDispose<List<InviteDetail>>((ref) async {
  try {
    return await ApiClient.instance.get(
      ApiConstants.myInvites,
      fromJson: (d) => ((d as Map<String, dynamic>)['invites'] as List? ?? [])
          .map((e) => InviteDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  } on AppError {
    return const []; // a hint, never a blocker
  }
});

class PendingInvitesBanner extends ConsumerWidget {
  const PendingInvitesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(pendingInvitesProvider).valueOrNull ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final inv in invites)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryMain),
            ),
            child: Row(
              children: [
                Icon(inv.typeIcon, color: AppColors.primaryMain, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You have an invite', style: AppTypography.h4),
                      const SizedBox(height: 2),
                      Text(
                        '${inv.nurseryName ?? 'A nursery'} invited you · ${inv.typeLabel}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () async {
                    await context.push('/invite/${inv.uuid}');
                    ref.invalidate(pendingInvitesProvider);
                  },
                  child: const Text('Review'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
