import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class NurseryRejectedScreen extends ConsumerStatefulWidget {
  const NurseryRejectedScreen({super.key});

  @override
  ConsumerState<NurseryRejectedScreen> createState() =>
      _NurseryRejectedScreenState();
}

class _NurseryRejectedScreenState extends ConsumerState<NurseryRejectedScreen> {
  String? _rejectionReason;
  DateTime? _rejectedAt;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadNurseryDetails();
  }

  Future<void> _loadNurseryDetails() async {
    final data = await ref.read(authRepositoryProvider).getOwnedNursery();
    if (!mounted) return;
    setState(() {
      _rejectionReason = data?['rejection_reason'] as String?;
      final rejectedRaw = data?['rejected_at'] as String?;
      _rejectedAt = rejectedRaw != null
          ? DateTime.tryParse(rejectedRaw)?.toLocal()
          : null;
      _loaded = true;
    });
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Application Status', style: AppTypography.h3),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.red600),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const Spacer(),

              // Status icon
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.red100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: AppColors.red600,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text(
                'Application Not Approved',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unfortunately, your nursery registration was not approved. Please review the reason below and resubmit.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              if (session.capabilities.ownedNurseryName != null) ...[
                const SizedBox(height: AppSpacing.x2l),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          color: AppColors.textMuted, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nursery',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary)),
                            Text(
                              session.capabilities.ownedNurseryName!,
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (_rejectedAt != null)
                              Text(
                                'Rejected on ${_formatDate(_rejectedAt!)}',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Rejected',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.red600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Rejection reason — shown when available
              if (_loaded && _rejectionReason?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.red50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.red600.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.red600, size: 16),
                          const SizedBox(width: 6),
                          Text('Reason for rejection',
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.red700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _rejectionReason!,
                        style: AppTypography.body
                            .copyWith(color: AppColors.red700),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x2l),

              // What to do next info
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.amber600.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: AppColors.amber700, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text('What you can do',
                            style: AppTypography.body.copyWith(
                                color: AppColors.amber700,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Tip('Address the reason mentioned above and resubmit.'),
                    _Tip('Contact GreenRoot support for more details.'),
                    _Tip(
                        'Ensure your contact details and documents are accurate.'),
                  ],
                ),
              ),

              const Spacer(),

              AppButton(
                label: 'Resubmit Application',
                onPressed: () => context.go('/register/nursery'),
                trailingIcon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _logout,
                child: Text(
                  'Sign Out',
                  style: AppTypography.button
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.amber700)),
          Expanded(
            child: Text(text,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.amber700)),
          ),
        ],
      ),
    );
  }
}
