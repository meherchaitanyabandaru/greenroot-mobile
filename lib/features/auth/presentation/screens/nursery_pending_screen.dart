import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class NurseryPendingScreen extends ConsumerStatefulWidget {
  const NurseryPendingScreen({super.key});

  @override
  ConsumerState<NurseryPendingScreen> createState() =>
      _NurseryPendingScreenState();
}

class _NurseryPendingScreenState extends ConsumerState<NurseryPendingScreen> {
  bool _refreshing = false;
  DateTime? _submittedAt;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadNurseryDetails();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !_refreshing) _refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNurseryDetails() async {
    final data = await ref.read(authRepositoryProvider).getOwnedNursery();
    if (!mounted) return;
    final createdAtRaw = data?['created_at'] as String?;
    if (createdAtRaw != null) {
      setState(() => _submittedAt = DateTime.tryParse(createdAtRaw)?.toLocal());
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await ref.read(sessionProvider.notifier).bootstrap();
    if (!mounted) return;
    setState(() => _refreshing = false);

    final caps = ref.read(sessionProvider).capabilities;
    if (caps.isNurseryOwner) {
      context.go('/home');
    } else if (caps.hasRejectedNursery) {
      context.go('/nursery/rejected');
    }
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
                  color: AppColors.amber100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: AppColors.amber600,
                  size: 44,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text(
                'Application Under Review',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your nursery registration is being reviewed by the GreenRoot team. You\'ll be notified once a decision is made.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              if (_submittedAt != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Submitted on ${_formatDate(_submittedAt!)}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x3l),

              // Steps
              _StatusStep(
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.primaryMain,
                title: 'Application Submitted',
                subtitle: _submittedAt != null
                    ? 'Received on ${_formatDate(_submittedAt!)}'
                    : 'Your nursery details have been received.',
              ),
              const SizedBox(height: AppSpacing.md),
              _StatusStep(
                icon: Icons.pending_rounded,
                iconColor: AppColors.amber600,
                title: 'Under Review',
                subtitle: 'GreenRoot is reviewing your application.',
                isActive: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _StatusStep(
                icon: Icons.circle_outlined,
                iconColor: AppColors.textMuted,
                title: 'Approval Decision',
                subtitle: 'You will be notified when approved.',
              ),

              const Spacer(),

              AppButton(
                label: 'Check Status',
                onPressed: _refreshing ? null : _refresh,
                isLoading: _refreshing,
                leadingIcon: Icons.refresh_rounded,
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

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isActive;

  const _StatusStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isActive ? AppColors.amber50 : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.amber600.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        isActive ? AppColors.amber700 : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
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
    );
  }
}
