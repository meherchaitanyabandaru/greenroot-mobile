import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/api_constants.dart';
import '../../network/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/qr_shared_widgets.dart';
import '../classifier.dart';
import '../qr_models.dart';
import '../../../features/auth/presentation/providers/session_provider.dart';

class InviteSheet extends ConsumerStatefulWidget {
  final String uuid;
  final VoidCallback onScanAnother;
  final void Function(QrSheetResult) onResult;

  const InviteSheet({
    super.key,
    required this.uuid,
    required this.onScanAnother,
    required this.onResult,
  });

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  QrInviteData? _invite;
  bool _loading = false;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiConstants.inviteByUUID(widget.uuid),
      );
      final inv = (body['invite'] is Map) ? body['invite'] as Map<String, dynamic> : body;
      setState(() {
        _loading = false;
        _invite = QrInviteData(
          uuid: (inv['invite_uuid'] ?? widget.uuid) as String,
          inviteType: (inv['invite_type'] ?? '') as String,
          inviterName: inv['inviter_name'] as String?,
          nurseryName: inv['nursery_name'] as String?,
          isPending: ((inv['status'] as String?) ?? '').toUpperCase() == 'PENDING',
        );
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load invite. It may have expired or already been used.';
      });
    }
  }

  Future<void> _accept() async {
    final invite = _invite;
    if (invite == null) return;
    setState(() => _accepting = true);
    try {
      await ApiClient.instance.post(ApiConstants.acceptInvite(invite.uuid));
      await ref.read(sessionProvider.notifier).bootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite accepted! Your access has been updated.'),
          backgroundColor: AppColors.primaryMain,
        ),
      );
      widget.onResult(QrSheetResult.close);
    } catch (e) {
      setState(() => _accepting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inviteErrorMessage(e)),
            backgroundColor: AppColors.red500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const QrLoadingSpinner();
    if (_error != null) {
      return QrErrorCard(message: _error!, onRetry: widget.onScanAnother);
    }
    final invite = _invite;
    if (invite == null) return const SizedBox.shrink();

    final typeLabel = switch (invite.inviteType) {
      'CUSTOMER_INVITE'           => 'Customer',
      'MANAGER_INVITE'            => 'Manager (Gumastha)',
      'DRIVER_INVITE'             => 'Driver',
      'NURSERY_ONBOARDING_INVITE' => 'Nursery Owner',
      'TRIP_SHARE_INVITE'         => 'Trip Assignment',
      _                           => invite.inviteType.replaceAll('_', ' '),
    };

    final subtitle = invite.nurseryName != null
        ? 'Invited by ${invite.inviterName ?? 'GreenRoot'} · ${invite.nurseryName}'
        : 'Invited by ${invite.inviterName ?? 'GreenRoot'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QrHeaderRow(
          icon: Icons.mail_outline_rounded,
          iconColor: AppColors.primaryMain,
          iconBg: AppColors.forest100,
          title: 'You have an invite',
          subtitle: subtitle,
        ),
        const SizedBox(height: 16),
        QrInfoCard(
          children: [
            QrInfoRow(
              icon: Icons.badge_outlined,
              label: 'Joining as',
              value: typeLabel,
              valueColor: AppColors.primaryMain,
            ),
          ],
        ),
        if (!invite.isPending) ...[
          const SizedBox(height: 12),
          QrWarningBanner('This invite has already been used or has expired.'),
        ],
        const SizedBox(height: 24),
        if (invite.isPending)
          FilledButton(
            onPressed: _accepting ? null : _accept,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _accepting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Accept Invite',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        if (invite.isPending) const SizedBox(height: 10),
        QrScanAnotherButton(onTap: widget.onScanAnother),
      ],
    );
  }
}
