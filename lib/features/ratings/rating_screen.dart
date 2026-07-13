import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'ratings.dart';

// ── App Feedback Screen ───────────────────────────────────────────────────────

class AppRatingScreen extends ConsumerStatefulWidget {
  const AppRatingScreen({super.key});

  @override
  ConsumerState<AppRatingScreen> createState() => _AppRatingScreenState();
}

class _AppRatingScreenState extends ConsumerState<AppRatingScreen> {
  int _rating = 0;
  bool? _wouldRecommend;
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(ratingRepositoryProvider).submitAppRating(
            overallRating: _rating,
            wouldRecommend: _wouldRecommend,
            comment: _commentCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: AppColors.primaryMain),
      );
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Feedback'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(
              icon: Icons.star_rounded,
              title: 'How was your experience with GreenRoot?',
              subtitle:
                  'Your feedback helps us improve the app and serve you better.',
            ),
            const SizedBox(height: AppSpacing.x2l),
            _StarRating(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
            const SizedBox(height: AppSpacing.x2l),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tell us more (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            Text('Would you recommend GreenRoot to others?',
                style: AppTypography.label),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _YesNoButton(
                  label: 'Yes',
                  icon: Icons.thumb_up_outlined,
                  selected: _wouldRecommend == true,
                  onTap: () => setState(() => _wouldRecommend = true),
                ),
                const SizedBox(width: AppSpacing.md),
                _YesNoButton(
                  label: 'No',
                  icon: Icons.thumb_down_outlined,
                  selected: _wouldRecommend == false,
                  onTap: () => setState(() => _wouldRecommend = false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Feedback'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trip Rating Screen ────────────────────────────────────────────────────────

class TripRatingScreen extends ConsumerStatefulWidget {
  final int dispatchId;
  final String? dispatchCode;

  const TripRatingScreen(
      {super.key, required this.dispatchId, this.dispatchCode});

  @override
  ConsumerState<TripRatingScreen> createState() => _TripRatingScreenState();
}

class _TripRatingScreenState extends ConsumerState<TripRatingScreen> {
  int _driverBehaviour = 0;
  int _onTime = 0;
  int _plantCondition = 0;
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(ratingRepositoryProvider).submitTripRating(
            dispatchId: widget.dispatchId,
            driverBehaviourRating: _driverBehaviour > 0 ? _driverBehaviour : null,
            onTimeDeliveryRating: _onTime > 0 ? _onTime : null,
            plantConditionRating: _plantCondition > 0 ? _plantCondition : null,
            comment: _commentCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Trip rated. Thank you!'),
            backgroundColor: AppColors.primaryMain),
      );
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Delivery'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(
              icon: Icons.local_shipping_outlined,
              title: 'Rate your delivery experience',
              subtitle: widget.dispatchCode != null
                  ? 'Trip ID: ${widget.dispatchCode}'
                  : null,
            ),
            const SizedBox(height: AppSpacing.x2l),
            _SubRatingRow(
              icon: Icons.person_outline,
              label: 'Driver behaviour',
              subtitle: "How was the driver's behaviour?",
              value: _driverBehaviour,
              onChanged: (v) => setState(() => _driverBehaviour = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SubRatingRow(
              icon: Icons.access_time_outlined,
              label: 'On-time delivery',
              subtitle: 'Was the delivery on time?',
              value: _onTime,
              onChanged: (v) => setState(() => _onTime = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SubRatingRow(
              icon: Icons.eco_outlined,
              label: 'Plant condition',
              subtitle: 'Condition of plants at delivery',
              value: _plantCondition,
              onChanged: (v) => setState(() => _plantCondition = v),
            ),
            const SizedBox(height: AppSpacing.x2l),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any comments? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Rating'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Rating Screen ───────────────────────────────────────────────────────

class OrderRatingScreen extends ConsumerStatefulWidget {
  final int orderId;
  final String? orderCode;

  const OrderRatingScreen({super.key, required this.orderId, this.orderCode});

  @override
  ConsumerState<OrderRatingScreen> createState() => _OrderRatingScreenState();
}

class _OrderRatingScreenState extends ConsumerState<OrderRatingScreen> {
  int _plantQuality = 0;
  int _communication = 0;
  int _overallExperience = 0;
  bool? _wouldBuyAgain;
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(ratingRepositoryProvider).submitOrderRating(
            orderId: widget.orderId,
            plantQualityRating: _plantQuality > 0 ? _plantQuality : null,
            communicationRating: _communication > 0 ? _communication : null,
            overallExperienceRating:
                _overallExperience > 0 ? _overallExperience : null,
            wouldBuyAgain: _wouldBuyAgain,
            comment: _commentCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order rated. Thank you!'),
            backgroundColor: AppColors.primaryMain),
      );
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Order'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(
              icon: Icons.inventory_2_outlined,
              title: 'Rate your order experience',
              subtitle: widget.orderCode != null
                  ? 'Order ID: ${widget.orderCode}'
                  : null,
            ),
            const SizedBox(height: AppSpacing.x2l),
            _SubRatingRow(
              icon: Icons.eco_outlined,
              label: 'Plant quality',
              subtitle: 'How was the quality of the plants?',
              value: _plantQuality,
              onChanged: (v) => setState(() => _plantQuality = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SubRatingRow(
              icon: Icons.chat_bubble_outline,
              label: 'Communication',
              subtitle: 'How was the communication with the nursery?',
              value: _communication,
              onChanged: (v) => setState(() => _communication = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SubRatingRow(
              icon: Icons.thumb_up_outlined,
              label: 'Overall experience',
              subtitle: 'Overall experience with this order',
              value: _overallExperience,
              onChanged: (v) => setState(() => _overallExperience = v),
            ),
            const SizedBox(height: AppSpacing.x2l),
            Text('Would you buy from this nursery again?',
                style: AppTypography.label),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _YesNoButton(
                  label: 'Yes',
                  icon: Icons.thumb_up_outlined,
                  selected: _wouldBuyAgain == true,
                  onTap: () => setState(() => _wouldBuyAgain = true),
                ),
                const SizedBox(width: AppSpacing.md),
                _YesNoButton(
                  label: 'No',
                  icon: Icons.thumb_down_outlined,
                  selected: _wouldBuyAgain == false,
                  onTap: () => setState(() => _wouldBuyAgain = false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2l),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any comments? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Rating'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

Widget _header(
    {required IconData icon,
    required String title,
    String? subtitle}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 40, color: AppColors.primaryMain),
      const SizedBox(height: AppSpacing.md),
      Text(title,
          style:
              AppTypography.h3.copyWith(color: AppColors.textPrimary)),
      if (subtitle != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    ],
  );
}

class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        return GestureDetector(
          onTap: () => onChanged(star),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 44,
              color: star <= value
                  ? AppColors.amber500
                  : AppColors.textMuted,
            ),
          ),
        );
      }),
    );
  }
}

class _SubRatingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  const _SubRatingRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, size: 20, color: AppColors.primaryMain),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.label),
              Text(subtitle,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  star <= value
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 24,
                  color: star <= value
                      ? AppColors.amber500
                      : AppColors.textMuted,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _YesNoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _YesNoButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMain : AppColors.surface,
          border: Border.all(
            color:
                selected ? AppColors.primaryMain : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.label.copyWith(
                    color:
                        selected ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
