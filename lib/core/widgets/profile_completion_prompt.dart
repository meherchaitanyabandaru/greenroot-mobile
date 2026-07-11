import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'profile_completion_card.dart';

/// Tracks whether the completion prompt has been shown this session.
/// Resets on cold start (StateProvider = in-memory only).
final completionPromptShownProvider = StateProvider<bool>((ref) => false);

/// Shows a modal bottom sheet prompting the user to complete their profile.
/// Should be called once per app session when completion < 90%.
Future<void> showCompletionPrompt(
  BuildContext context,
  WidgetRef ref, {
  required List<CompletionItem> items,
  required double percent,
  VoidCallback? onCompleteNow,
}) async {
  ref.read(completionPromptShownProvider.notifier).state = true;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompletionSheet(
      items: items,
      percent: percent,
      onCompleteNow: onCompleteNow,
    ),
  );
}

class _CompletionSheet extends StatelessWidget {
  final List<CompletionItem> items;
  final double percent;
  final VoidCallback? onCompleteNow;

  const _CompletionSheet({
    required this.items,
    required this.percent,
    this.onCompleteNow,
  });

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percent * 100).round()}%';
    final pending = items.where((i) => !i.done).toList();
    final done = items.where((i) => i.done).length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Progress ring + text
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x2l,
              AppSpacing.x2l,
              AppSpacing.x2l,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                _ProgressRing(percent: percent, size: 72),
                const SizedBox(width: AppSpacing.x2l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete your profile',
                        style: AppTypography.h3,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your profile is $pctLabel complete ($done of ${items.length} done). '
                        'Complete at least 90% for the best experience.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Pending items only (actionable)
          if (pending.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: pending.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) =>
                    _SheetItem(item: pending[i], context: context),
              ),
            ),

          // Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppSpacing.buttonHeight,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (onCompleteNow != null) {
                          onCompleteNow!();
                          return;
                        }

                        final first =
                            pending.where((i) => i.onTap != null).firstOrNull;
                        first?.onTap?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(
                          double.infinity,
                          AppSpacing.buttonHeight,
                        ),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                      child: const Text('Complete Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final CompletionItem item;
  final BuildContext context;

  const _SheetItem({required this.item, required this.context});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.onTap != null) {
          Navigator.pop(context);
          item.onTap!();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.radio_button_unchecked_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(item.label, style: AppTypography.body),
            ),
            if (item.onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Animated progress ring ────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double percent;
  final double size;

  const _ProgressRing({required this.percent, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 0.8
        ? AppColors.primaryMain
        : percent >= 0.5
            ? AppColors.amber600
            : AppColors.red500;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              percent: percent,
              trackColor: AppColors.border,
              fillColor: color,
              strokeWidth: 6,
            ),
          ),
          Text(
            '${(percent * 100).round()}%',
            style: AppTypography.label.copyWith(
              color: color,
              fontSize: size * 0.22,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  const _RingPainter({
    required this.percent,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.fillColor != fillColor;
}
