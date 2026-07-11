import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../nurseries/nurseries.dart';

const _dismissedKeyPrefix = 'nursery_setup_dismissed_';

/// Returns true if the setup prompt for [nurseryId] has been permanently dismissed.
final nurserySetupDismissedProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, nurseryId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_dismissedKeyPrefix$nurseryId') ?? false;
});

/// One-time post-approval checklist shown on the owner home when the nursery
/// is ACTIVE but has no branding or primary address. Never shows again after dismiss.
class NurserySetupPrompt extends ConsumerWidget {
  const NurserySetupPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;
    final nurseryId = caps.ownedNurseryId;

    // Only render for active owners with a nursery ID
    if (!caps.isNurseryOwner || nurseryId == null) return const SizedBox.shrink();

    final dismissedAsync = ref.watch(nurserySetupDismissedProvider(nurseryId));
    final nurseryAsync = ref.watch(nurseryDetailProvider(nurseryId));

    return dismissedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dismissed) {
        if (dismissed) return const SizedBox.shrink();
        return nurseryAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (nursery) {
            final needsBranding = (nursery.logoUrl?.isEmpty ?? true) &&
                (nursery.brandIconKey?.isEmpty ?? true);
            final needsAddress = nursery.addresses.isEmpty;
            if (!needsBranding && !needsAddress) return const SizedBox.shrink();

            return _SetupPromptCard(
              nursery: nursery,
              needsBranding: needsBranding,
              needsAddress: needsAddress,
              onDismiss: () => _dismiss(ref, nurseryId),
            );
          },
        );
      },
    );
  }

  static Future<void> _dismiss(WidgetRef ref, int nurseryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_dismissedKeyPrefix$nurseryId', true);
    ref.invalidate(nurserySetupDismissedProvider(nurseryId));
  }
}

class _SetupPromptCard extends StatelessWidget {
  final Nursery nursery;
  final bool needsBranding;
  final bool needsAddress;
  final VoidCallback onDismiss;

  const _SetupPromptCard({
    required this.nursery,
    required this.needsBranding,
    required this.needsAddress,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x2l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primaryMain.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set up your nursery',
                          style: AppTypography.label),
                      Text(
                        'A few quick steps to get started',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Checklist items
          if (needsBranding)
            _PromptItem(
              icon: Icons.palette_outlined,
              color: AppColors.purple500,
              title: 'Add your nursery branding',
              subtitle: 'Upload a logo or pick an icon and color',
              onTap: () => context.push('/nursery/branding',
                  extra: nursery.id),
            ),
          if (needsAddress)
            _PromptItem(
              icon: Icons.location_on_outlined,
              color: AppColors.blue600,
              title: 'Add a nursery address',
              subtitle: 'Shown on quotations and orders',
              onTap: () => context.push('/nurseries/${nursery.id}'),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _PromptItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PromptItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body),
                  Text(subtitle,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
