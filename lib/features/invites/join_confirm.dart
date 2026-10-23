import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Who and where an invite comes from. Shown before joining, because two
/// nurseries can share a name and a wrong scan would make someone work for
/// the wrong nursery.
class InviteFacts {
  final String inviteType;
  final String? nurseryName;
  final String? ownerName;
  final String? ownerMobileHint; // last 4 digits
  final String? place;
  final String? inviterName;

  const InviteFacts({
    required this.inviteType,
    this.nurseryName,
    this.ownerName,
    this.ownerMobileHint,
    this.place,
    this.inviterName,
  });

  factory InviteFacts.fromJson(Map<String, dynamic> j) => InviteFacts(
        inviteType: j['invite_type'] as String? ?? '',
        nurseryName: j['nursery_name'] as String?,
        ownerName: j['owner_name'] as String?,
        ownerMobileHint: j['owner_mobile_hint'] as String?,
        place: j['nursery_place'] as String?,
        inviterName: j['inviter_name'] as String?,
      );

  /// Working for a nursery: worth a deliberate "yes".
  bool get needsConfirm =>
      inviteType == 'MANAGER_INVITE' || inviteType == 'DRIVER_INVITE';

  String get roleLabel => switch (inviteType) {
        'MANAGER_INVITE' => 'manager',
        'DRIVER_INVITE' => 'driver',
        'CUSTOMER_INVITE' => 'customer',
        _ => 'member',
      };

  String? get roleDuties => switch (inviteType) {
        'MANAGER_INVITE' =>
          "As a manager you will see and handle this nursery's orders, quotations and deliveries.",
        'DRIVER_INVITE' => "You will deliver this nursery's orders.",
        _ => null,
      };

  /// "Suresh Owner · mobile ending 0001"
  String? get ownerLine {
    final parts = [
      if (ownerName != null) ownerName!,
      if (ownerMobileHint != null) 'mobile ending $ownerMobileHint',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The inviter, when it is not the owner (e.g. a manager sent it).
  String? get otherInviter =>
      inviterName != null && inviterName != ownerName ? inviterName : null;
}

/// Owner / place / inviter rows for an invite card.
class InviteFactRows extends StatelessWidget {
  final InviteFacts facts;
  const InviteFactRows({super.key, required this.facts});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text(label,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted),),
              ),
              Expanded(
                child: Text(value,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.ownerLine != null)
          row(Icons.person_outline_rounded, 'Owner', facts.ownerLine!),
        if (facts.place != null)
          row(Icons.place_outlined, 'Place', facts.place!),
        if (facts.otherInviter != null)
          row(Icons.send_outlined, 'Invited by', facts.otherInviter!),
        if (facts.roleDuties != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(facts.roleDuties!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),),
          ),
      ],
    );
  }
}

/// "Join Suresh Green Nursery as manager?" — true when the user confirms.
/// Invites that don't make you work for a nursery pass straight through.
Future<bool> confirmJoinNursery(BuildContext context, InviteFacts facts) async {
  if (!facts.needsConfirm) return true;
  final nursery = facts.nurseryName ?? 'this nursery';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Join $nursery as ${facts.roleLabel}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InviteFactRows(facts: facts),
          const SizedBox(height: 14),
          Text(
            'Only join if this is the nursery you work for. If anything looks '
            'wrong, call the owner before joining.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.amber700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          // The theme makes filled buttons full width; not in a dialog row.
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes, join'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
