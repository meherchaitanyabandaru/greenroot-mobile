import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import 'invite_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dashboard/owner/owner_dashboard_data.dart';

// ── Connections Screen ────────────────────────────────────────────────────────
//
// INVITE API RULE (service.go line 62):
//   Both MANAGER_INVITE and CUSTOMER_INVITE require target_mobile OR target_email.
//   Invite is person-specific — UUID/QR is then shared with that person.
//
// Sections (order):
//   1. Customers  — buyers who've ordered or accepted CUSTOMER_INVITE
//   2. Managers (Gumastha) — staff via MANAGER_INVITE
//   3. Drivers — independent delivery partners

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref, {
    required String inviteType,
    required int nurseryId,
    required QrCodeType qrType,
  }) async {
    final isCustomer = inviteType == 'CUSTOMER_INVITE';
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _InviteSheet(
        isCustomer: isCustomer,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final invite = await ref.read(inviteRepositoryProvider).sendInvite(
            inviteType: inviteType,
            nurseryId: nurseryId,
            targetMobile: result['mobile'],
            targetName: result['name'],
          );
      ref.invalidate(ownerDashboardProvider);
      final uuid = invite['invite_uuid'] as String? ?? '';
      final expiresAt = invite['expires_at'] != null
          ? DateTime.tryParse(invite['expires_at'] as String)
          : null;
      if (uuid.isNotEmpty && context.mounted) {
        await QrShareSheet.show(
          context,
          code: uuid,
          qrType: qrType,
          expiresAt: expiresAt,
        );
      }
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.red600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not create invite. Try again.'),
          backgroundColor: AppColors.red600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final session = ref.watch(sessionProvider);
    final nurseryId = session.nurseryId;
    final nurseryName = session.capabilities.ownedNurseryName ?? 'My Nursery';
    final counts = dashboard.valueOrNull?.connections;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My People', style: AppTypography.h3),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ownerDashboardProvider.future),
        color: AppColors.primaryMain,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // ── 1. Customers ─────────────────────────────────────────────────
            _ConnectionCard(
              icon: Icons.people_alt_rounded,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: AppColors.primaryMain,
              title: 'Customers',
              subtitle: 'Buyers who have placed orders or accepted invites from $nurseryName',
              count: counts?.customers,
              actionLabel: 'Invite Customer',
              actionIcon: Icons.qr_code_rounded,
              onAction: nurseryId != null
                  ? () => _invite(
                        context, ref,
                        inviteType: 'CUSTOMER_INVITE',
                        nurseryId: nurseryId,
                        qrType: QrCodeType.customerInvite,
                      )
                  : null,
              onViewAll: nurseryId != null
                  ? () => context.push(Uri(
                        path: '/nursery/members',
                        queryParameters: {
                          'id': '$nurseryId',
                          'name': nurseryName,
                          'tab': '1',
                        },
                      ).toString())
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── 2. Managers (Gumastha) ────────────────────────────────────────
            _ConnectionCard(
              icon: Icons.manage_accounts_rounded,
              iconBg: const Color(0xFFE3F2FD),
              iconColor: AppColors.blue600,
              title: 'Managers (Gumastha)',
              subtitle: 'Staff who manage day-to-day nursery operations at $nurseryName',
              count: counts?.managers,
              actionLabel: 'Invite Gumastha',
              actionIcon: Icons.qr_code_rounded,
              onAction: nurseryId != null
                  ? () => _invite(
                        context, ref,
                        inviteType: 'MANAGER_INVITE',
                        nurseryId: nurseryId,
                        qrType: QrCodeType.managerInvite,
                      )
                  : null,
              onViewAll: nurseryId != null
                  ? () => context.push(Uri(
                        path: '/nursery/members',
                        queryParameters: {
                          'id': '$nurseryId',
                          'name': nurseryName,
                          'tab': '0',
                        },
                      ).toString())
                  : null,
            ),

            const SizedBox(height: AppSpacing.x3l),
          ],
        ),
      ),
    );
  }
}

// ── Connection card ───────────────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int? count;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final VoidCallback? onViewAll;

  const _ConnectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.count,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: AppTypography.h4,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (count != null && count! > 0)
                            Container(
                              margin: const EdgeInsets.only(left: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '$count',
                                style: AppTypography.caption.copyWith(
                                  color: iconColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onViewAll != null || (actionLabel != null && onAction != null))
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (onViewAll != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onViewAll,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('View All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                      ),
                    ),
                  if (onViewAll != null && actionLabel != null && onAction != null)
                    const SizedBox(
                      height: 40,
                      child: VerticalDivider(width: 1, color: AppColors.border),
                    ),
                  if (actionLabel != null && onAction != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.add_rounded, size: 16),
                        label: Text(actionLabel!),
                        style: TextButton.styleFrom(
                          foregroundColor: iconColor,
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared invite bottom sheet ────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final bool isCustomer;
  const _InviteSheet({required this.isCustomer});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _mobileCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid 10-digit mobile number'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.of(context).pop({'mobile': mobile, 'name': _nameCtrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.isCustomer;
    final iconColor = isCustomer ? AppColors.primaryMain : AppColors.blue600;
    final iconBg = isCustomer ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD);
    final icon = isCustomer ? Icons.people_alt_rounded : Icons.manage_accounts_rounded;
    final title = isCustomer ? 'Invite Customer' : 'Invite Gumastha';
    final subtitle = isCustomer
        ? 'Generate a QR code to share with your customer'
        : 'Generate a QR code to share with your manager';
    final mobileLabel = isCustomer ? 'Customer Mobile *' : 'Gumastha Mobile *';
    final nameLabel = isCustomer ? 'Customer Name (optional)' : 'Gumastha Name (optional)';
    final nameHint = isCustomer ? 'e.g. Ravi Kumar' : 'e.g. Suresh Gumastha';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x2l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.h4),
                    Text(subtitle,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          TextField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: mobileLabel,
              hintText: '10-digit mobile number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: nameLabel,
              hintText: nameHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: const Text('Generate Invite QR'),
              style: FilledButton.styleFrom(
                backgroundColor: iconColor,
                textStyle: AppTypography.button,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
