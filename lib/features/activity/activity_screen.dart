import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Activity', style: AppTypography.h3),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 36,
                  color: AppColors.primaryMain,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Transaction Timeline', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A unified timeline of all your selling and buying activity — quotations, orders, dispatches, and deliveries — will appear here.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
