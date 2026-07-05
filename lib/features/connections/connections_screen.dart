import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../dashboard/owner/owner_dashboard_data.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  Future<void> _inviteCustomer(
      BuildContext context, int nurseryId) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _InviteCustomerSheet(),
    );
    if (result == null || !context.mounted) return;

    try {
      final body = <String, dynamic>{
        'invite_type': 'CUSTOMER_INVITE',
        'nursery_id': nurseryId,
        'target_mobile': result['mobile'],
        if ((result['name'] ?? '').isNotEmpty) 'target_name': result['name'],
      };
      final data = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/v1/invites',
        data: body,
      );
      final invite = (data['invite'] ?? data) as Map<String, dynamic>;
      final uuid = invite['invite_uuid'] as String? ?? '';
      final expiresRaw = invite['expires_at'] as String?;
      final expiresAt =
          expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;
      if (uuid.isNotEmpty && context.mounted) {
        await QrShareSheet.show(
          context,
          code: uuid,
          qrType: QrCodeType.customerInvite,
          expiresAt: expiresAt,
        );
      }
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.red600,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not create invite. Try again.'),
          backgroundColor: AppColors.red600,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final session = ref.watch(sessionProvider);
    final nurseryId = session.nurseryId;
    final nurseryName = session.capabilities.ownedNurseryName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Connections'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ownerDashboardProvider.future),
        color: AppColors.primaryMain,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // Description
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      color: AppColors.primaryMain, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Connections stay permanently once added — '
                      'like a professional network built on trust.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.forest600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // Managers
            _ConnectionCard(
              icon: Icons.manage_accounts_rounded,
              iconBg: AppColors.teal100,
              iconColor: AppColors.teal700,
              title: 'Managers',
              subtitle: 'Gumasthas who manage your nursery operations',
              count: dashboard.when(
                data: (d) => d.connections.managers,
                loading: () => null,
                error: (_, __) => null,
              ),
              actionLabel: 'Invite Manager',
              actionIcon: Icons.person_add_alt_1_rounded,
              onAction: () {
                if (nurseryId != null) {
                  context.push('/nursery/members',
                      extra: {'id': nurseryId, 'name': nurseryName ?? 'My Nursery', 'tab': 1});
                }
              },
              onViewAll: nurseryId != null
                  ? () => context.push(
                      '/nursery/members?id=$nurseryId&name=${Uri.encodeComponent(nurseryName ?? 'My Nursery')}&tab=0')
                  : null,
            ),

            const SizedBox(height: AppSpacing.md),

            // Drivers
            _ConnectionCard(
              icon: Icons.local_shipping_rounded,
              iconBg: AppColors.amber100,
              iconColor: AppColors.amber600,
              title: 'Delivery Drivers',
              subtitle: 'Create a dispatch from a loaded order to assign a driver',
              count: dashboard.when(
                data: (d) => d.connections.drivers,
                loading: () => null,
                error: (_, __) => null,
              ),
              actionLabel: 'Create Dispatch',
              actionIcon: Icons.local_shipping_rounded,
              onAction: () => context.push('/orders'),
              onViewAll: () => context.push('/dispatches'),
            ),

            const SizedBox(height: AppSpacing.md),

            // Customers
            _ConnectionCard(
              icon: Icons.people_alt_rounded,
              iconBg: AppColors.blue100,
              iconColor: AppColors.blue600,
              title: 'Customers',
              subtitle: 'Buyers who have placed orders with your nursery',
              count: dashboard.when(
                data: (d) => d.connections.customers,
                loading: () => null,
                error: (_, __) => null,
              ),
              actionLabel: 'Invite via QR',
              actionIcon: Icons.qr_code_rounded,
              onAction: nurseryId != null
                  ? () => _inviteCustomer(context, nurseryId)
                  : null,
              onViewAll: nurseryId != null
                  ? () => context.push('/orders?nursery=$nurseryId')
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
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
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
                          Text(title, style: AppTypography.h4),
                          if (count != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '$count',
                                style: AppTypography.caption.copyWith(
                                  color: iconColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null || onViewAll != null)
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
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                        ),
                      ),
                    ),
                  if (onViewAll != null && actionLabel != null)
                    const SizedBox(
                      height: 40,
                      child: VerticalDivider(
                          width: 1, color: AppColors.border),
                    ),
                  if (actionLabel != null && onAction != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.add_rounded, size: 16),
                        label: Text(actionLabel!),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryMain,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
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

// ── Invite customer bottom sheet ───────────────────────────────────────────────

class _InviteCustomerSheet extends StatefulWidget {
  const _InviteCustomerSheet();

  @override
  State<_InviteCustomerSheet> createState() => _InviteCustomerSheetState();
}

class _InviteCustomerSheetState extends State<_InviteCustomerSheet> {
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
    Navigator.of(context)
        .pop({'mobile': mobile, 'name': _nameCtrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_rounded,
                    color: AppColors.blue600, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite Customer', style: AppTypography.h4),
                    Text(
                      'Generate a QR code to share with your customer',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
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
              labelText: 'Customer Mobile *',
              hintText: '10-digit mobile number',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Customer Name (optional)',
              hintText: 'e.g. Ravi Kumar',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                backgroundColor: AppColors.primaryMain,
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
